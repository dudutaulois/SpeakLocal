#!/usr/bin/env python3
"""SpeakLocal TTS engine — synthesizes text to WAV using Kokoro-82M on Apple Silicon."""

import argparse
import json
import sys


def synthesize(text: str, voice: str, speed: float, output: str, sample_rate: int) -> dict:
    from kokoro_mlx import KokoroTTS

    tts = KokoroTTS.from_pretrained("mlx-community/Kokoro-82M-bf16")
    result = tts.save(
        text,
        output,
        voice=voice,
        speed=speed,
        sample_rate=sample_rate,
    )
    return {
        "output": output,
        "duration": result.duration,
        "sample_rate": result.sample_rate,
        "voice": result.voice,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="SpeakLocal Kokoro TTS engine")
    parser.add_argument("--text", help="Text to synthesize")
    parser.add_argument("--voice", default="af_heart", help="Voice name")
    parser.add_argument("--speed", type=float, default=1.0, help="Speaking rate")
    parser.add_argument("--output", help="Output WAV path")
    parser.add_argument(
        "--sample-rate",
        type=int,
        default=48000,
        choices=[24000, 48000],
        help="Output sample rate",
    )
    parser.add_argument("--warmup", action="store_true", help="Load model and exit")
    args = parser.parse_args()

    try:
        if args.warmup:
            from kokoro_mlx import KokoroTTS
            KokoroTTS.from_pretrained("mlx-community/Kokoro-82M-bf16")
            print(json.dumps({"status": "ready"}))
            return 0

        if not args.text or not args.output:
            parser.error("--text and --output are required unless using --warmup")

        meta = synthesize(args.text, args.voice, args.speed, args.output, args.sample_rate)
        print(json.dumps(meta))
        return 0
    except Exception as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
