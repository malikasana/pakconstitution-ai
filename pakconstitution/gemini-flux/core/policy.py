"""
gemini-flux — Smart Policy Fetcher
Asks Gemini about its own free tier limits and caches the result.
"""

import json
import os
import time
from google import genai

CACHE_FILE = ".gemini_flux_policy_cache.json"
CACHE_TTL_DAYS = 7

FALLBACK_POLICY = {
    "pro": {
        "requests_per_day": 100,
        "tokens_per_minute": 250000,
        "requests_per_minute": 2
    },
    "flash": {
        "requests_per_day": 250,
        "tokens_per_minute": 250000,
        "requests_per_minute": 10
    },
    "flash_lite": {
        "requests_per_day": 1000,
        "tokens_per_minute": 250000,
        "requests_per_minute": 15
    },
    "token_cooldown_seconds": 240,
    "daily_reset_time_pt": "00:00"
}

POLICY_PROMPT = """You are a data provider. Return ONLY a raw JSON object.
No markdown, no backticks, no explanation, no preamble, no trailing text.
Use this exact schema with real current Gemini free tier API limit values:

{
  "pro": {
    "requests_per_day": <integer>,
    "tokens_per_minute": <integer>,
    "requests_per_minute": <integer>
  },
  "flash": {
    "requests_per_day": <integer>,
    "tokens_per_minute": <integer>,
    "requests_per_minute": <integer>
  },
  "flash_lite": {
    "requests_per_day": <integer>,
    "tokens_per_minute": <integer>,
    "requests_per_minute": <integer>
  },
  "token_cooldown_seconds": <integer>,
  "daily_reset_time_pt": "<HH:MM>"
}

Only return the JSON. Nothing else."""


def _load_cache():
    if not os.path.exists(CACHE_FILE):
        return None
    try:
        with open(CACHE_FILE, "r") as f:
            data = json.load(f)
        age_days = (time.time() - data.get("fetched_at", 0)) / 86400
        if age_days > CACHE_TTL_DAYS:
            print(f"[POLICY] Cache is {age_days:.1f} days old — refreshing")
            return None
        print(f"[POLICY] Using cached policy ({age_days:.1f} days old)")
        return data.get("policy")
    except Exception:
        return None


def _save_cache(policy: dict):
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump({"fetched_at": time.time(), "policy": policy}, f, indent=2)
    except Exception as e:
        print(f"[POLICY] ⚠️  Could not save cache: {e}")


def fetch_policy(api_key: str, force: bool = False) -> tuple:
    if not force:
        cached = _load_cache()
        if cached:
            return cached, False

    print("[POLICY] Fetching current Gemini free tier limits...")
    try:
        client = genai.Client(api_key=api_key)
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=POLICY_PROMPT
        )
        raw = response.text.strip()

        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        raw = raw.strip()

        policy = json.loads(raw)
        _save_cache(policy)
        print("[POLICY] ✅ Policy fetched and cached successfully")
        return policy, True

    except json.JSONDecodeError as e:
        print(f"[POLICY] ⚠️  Could not parse response: {e} — using fallback")
        return FALLBACK_POLICY, True
    except Exception as e:
        print(f"[POLICY] ⚠️  Fetch failed: {e} — using fallback")
        return FALLBACK_POLICY, True