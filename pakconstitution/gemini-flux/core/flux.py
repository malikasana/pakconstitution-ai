"""
gemini-flux — Main Interface
Give it N keys. It manages everything. You just call generate().
"""

import time
import threading
from typing import Optional
from google import genai

from .policy import fetch_policy, FALLBACK_POLICY
from .key_pool import build_key_pool, KeyStatus, MODEL_CHAIN
from .scheduler import Scheduler


class GeminiFlux:
    def __init__(
        self,
        keys: list,
        mode: str = "both",
        log: bool = True,
        force_policy_refresh: bool = False
    ):
        assert len(keys) > 0, "Provide at least 1 API key"
        assert mode in ("both", "pro_only", "flash_only", "flash_lite_only")

        self.mode = mode
        self.log = log
        self._lock = threading.Lock()

        print(f"\n{'='*50}")
        print(f"  gemini-flux 🔥  Starting up with {len(keys)} keys")
        print(f"{'='*50}\n")

        # Step 1: Validate all keys
        self.pool = build_key_pool(keys)

        # Step 2: Show available model chain
        print(f"\n[MODELS] Exhaustion chain:")
        for i, model in enumerate(MODEL_CHAIN, 1):
            print(f"  {i}. {model}")

        # Step 3: Fetch policy using first healthy key
        healthy_keys = [k for k in self.pool if k.status == KeyStatus.HEALTHY]
        if not healthy_keys:
            print("[STARTUP] ⚠️  No healthy keys found! Using fallback policy.")
            self.policy = FALLBACK_POLICY
        else:
            policy, used_request = fetch_policy(
                api_key=healthy_keys[0].api_key,
                force=force_policy_refresh
            )
            self.policy = policy
            if used_request:
                healthy_keys[0].record_usage(500, "gemini-2.5-flash")
                print(f"\n[STARTUP] 1 request used on Key #{healthy_keys[0].index} for policy setup")

        # Step 4: Init scheduler
        self.scheduler = Scheduler(policy=self.policy, mode=mode)

        # Step 5: Show dynamic interval
        n_healthy = len([k for k in self.pool if k.status == KeyStatus.HEALTHY])
        if n_healthy > 0:
            cooldown = self.policy["token_cooldown_seconds"]
            interval = cooldown / n_healthy
            print(f"[STARTUP] Dynamic interval: {cooldown}s / {n_healthy} keys = {interval:.1f}s per request (worst case)")

        # Step 6: Start daily reset thread
        self._start_daily_reset()

        print(f"\n[STARTUP] ✅ gemini-flux ready! Mode: {mode.upper()}")
        print(f"{'='*50}\n")

    def generate(
        self,
        prompt: str,
        images: list = None,
        files: list = None,
        mode: str = None,
        preferred_key: int = None,
        max_tokens: int = 1000,
        temperature: float = 0.7,
        retry: bool = True
    ) -> dict:
        with self._lock:
            return self._generate_internal(
                prompt=prompt,
                images=images or [],
                files=files or [],
                mode_override=mode,
                preferred_key=preferred_key,
                max_tokens=max_tokens,
                temperature=temperature,
                retry=retry,
                attempt=1
            )

    def _generate_internal(self, prompt, images, files, mode_override,
                           preferred_key, max_tokens, temperature, retry, attempt):
        active_mode = mode_override or self.mode
        prompt_parts = [prompt] + images + files

        healthy = [k for k in self.pool if k.status == KeyStatus.HEALTHY]
        if not healthy:
            return {"error": "No healthy keys available. All exhausted or invalid."}

        # Count tokens FREE
        token_count = self.scheduler.count_tokens(healthy[0], prompt_parts)
        if self.log:
            print(f"[REQUEST] Incoming — {token_count:,} tokens detected")

        # Handle preferred key
        pool_to_use = self.pool
        if preferred_key is not None:
            matches = [k for k in self.pool if k.index == preferred_key
                      and k.status == KeyStatus.HEALTHY]
            if matches:
                pool_to_use = matches
                if self.log:
                    print(f"[REQUEST] Using preferred Key #{preferred_key}")
            else:
                if self.log:
                    print(f"[REQUEST] ⚠️  Preferred Key #{preferred_key} not available — auto-selecting")

        # Override mode temporarily
        original_mode = self.scheduler.mode
        self.scheduler.mode = active_mode
        key, model, wait = self.scheduler.pick_key(pool_to_use, token_count)
        self.scheduler.mode = original_mode

        if key is None:
            return {"error": "All keys and models exhausted for today. Resets at midnight PT."}

        # Wait if needed
        if wait > 0:
            if self.log:
                print(f"[SCHEDULER] ⏳ Key #{key.index} needs {wait:.1f}s cooldown — waiting...")
            time.sleep(wait)

        if self.log:
            print(f"[SCHEDULER] Key #{key.index} selected — sending via {model}")

        # Send request
        try:
            client = genai.Client(api_key=key.api_key)
            response = client.models.generate_content(
                model=model,
                contents=prompt_parts,
                config=genai.types.GenerateContentConfig(
                    max_output_tokens=max_tokens,
                    temperature=temperature
                )
            )
            key.record_usage(token_count, model)

            if self.log:
                used = key.requests_today.get(model, 0)
                rpd = self.policy.get(
                    "pro" if "pro" in model else "flash_lite" if "lite" in model else "flash",
                    {}
                ).get("requests_per_day", "?")
                print(f"[RESPONSE] ✅ Success via Key #{key.index} ({model})")
                print(f"[KEY {key.index}] {model}: {used}/{rpd} requests used today")

            return {
                "response": response.text,
                "key_used": key.index,
                "model_used": model,
                "tokens_used": token_count,
                "wait_applied": round(wait, 2),
                "retried": attempt > 1
            }

        except Exception as e:
            err = str(e).lower()
            if self.log:
                print(f"[KEY {key.index}] ❌ Request failed: {e}")

            if "quota" in err or "429" in err or "exhausted" in err:
                # Mark this model as exhausted for this key
                rpd = self.scheduler._get_rpd(model)
                key.requests_today[model] = rpd
                if self.log:
                    print(f"[KEY {key.index}] ⚠️  {model} marked exhausted — will try next model")
            elif "invalid" in err or "400" in err or "api_key" in err:
                key.status = KeyStatus.INVALID
                if self.log:
                    print(f"[KEY {key.index}] ❌ Marked INVALID")

            if retry and attempt < len(self.pool) * len(MODEL_CHAIN):
                if self.log:
                    print(f"[RETRY] Retrying (attempt {attempt + 1})")
                return self._generate_internal(
                    prompt, images, files, mode_override,
                    preferred_key=None, max_tokens=max_tokens,
                    temperature=temperature, retry=retry, attempt=attempt + 1
                )

            return {"error": str(e), "key_used": key.index, "retried": attempt > 1}

    def status(self) -> dict:
        result = []
        for key in self.pool:
            models_status = {}
            for model in MODEL_CHAIN:
                rpd = self.scheduler._get_rpd(model)
                used = key.requests_today.get(model, 0)
                models_status[model] = {
                    "used_today": used,
                    "remaining_today": max(0, rpd - used)
                }
            result.append({
                "key_index": key.index,
                "status": key.status.value,
                "models": models_status,
                "last_used_at": key.last_used_at
            })
        return {"keys": result, "mode": self.mode, "policy": self.policy}

    def set_mode(self, mode: str):
        assert mode in ("both", "pro_only", "flash_only", "flash_lite_only")
        self.mode = mode
        self.scheduler.mode = mode
        if self.log:
            print(f"[CONFIG] Mode changed to: {mode.upper()}")

    def refresh_policy(self):
        healthy = [k for k in self.pool if k.status == KeyStatus.HEALTHY]
        if not healthy:
            print("[POLICY] No healthy keys available")
            return
        policy, _ = fetch_policy(api_key=healthy[0].api_key, force=True)
        self.policy = policy
        self.scheduler.policy = policy
        print("[POLICY] ✅ Policy refreshed")

    def disable_key(self, index: int):
        for key in self.pool:
            if key.index == index:
                key.status = KeyStatus.INVALID
                print(f"[CONFIG] Key #{index} manually disabled")
                return
        print(f"[CONFIG] Key #{index} not found")

    def enable_key(self, index: int):
        for key in self.pool:
            if key.index == index:
                key.status = KeyStatus.HEALTHY
                print(f"[CONFIG] Key #{index} re-enabled")
                return

    def _start_daily_reset(self):
        def reset_loop():
            while True:
                try:
                    import pytz
                    from datetime import datetime, timedelta
                    pt = pytz.timezone("America/Los_Angeles")
                    now_pt = datetime.now(pt)
                    midnight = now_pt.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)
                    seconds_until = (midnight - now_pt).total_seconds()
                except Exception:
                    seconds_until = 86400

                time.sleep(seconds_until)
                print("\n[RESET] 🌅 Midnight PT — resetting daily quotas...")
                for key in self.pool:
                    key.reset_daily()
                print("[RESET] ✅ All keys reset\n")

        t = threading.Thread(target=reset_loop, daemon=True)
        t.start()