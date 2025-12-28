#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 <youtube_url> -mp3|-mp4"
  echo "Example: $0 \"https://www.youtube.com/watch?v=Yo0SRlDgCPs\" -mp3"
  exit 1
}

URL="${1:-}"
MODE="${2:-}"

[ -z "$URL" ] && usage
[ -z "$MODE" ] && usage
if [ "$MODE" != "-mp3" ] && [ "$MODE" != "-mp4" ]; then
  usage
fi

# Dependencies
command -v yt-dlp >/dev/null 2>&1 || { echo "yt-dlp not found. Install: brew install yt-dlp"; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found. Install: brew install ffmpeg"; exit 1; }

# Basic URL sanity check
if [[ "$URL" == *"\\?"* || "$URL" == *"\\="* ]]; then
  echo "❌ Ton URL contient des backslashes (\\). N'échappe pas ? et =."
  echo "✅ Exemple: https://www.youtube.com/watch?v=7CGKeID7nRc"
  exit 1
fi

# Get title safely (works for single videos and playlists)
TITLE="$(yt-dlp --yes-playlist --print "%(playlist_title,channel_title,title)s" --skip-download "$URL" 2>/dev/null | head -n 1 || true)"
if [ -z "$TITLE" ]; then
  echo "❌ Impossible de lire le titre. Vérifie l'URL."
  exit 1
fi

SAFE_TITLE="$(echo "$TITLE" | tr '/\\:*?"<>|' '_' )"
mkdir -p "audio/$SAFE_TITLE" "video/$SAFE_TITLE"

if [ "$MODE" = "-mp4" ]; then
  yt-dlp \
    --ignore-errors --no-warnings \
    -f "bestvideo[height<=1080][vcodec^=avc1]+bestaudio[acodec^=mp4a]/best[height<=1080]" \
    --merge-output-format mp4 \
    -o "video/$SAFE_TITLE/%(title)s.%(ext)s" \
    --yes-playlist "$URL" \
    --download-archive "video/$SAFE_TITLE/downloaded_${SAFE_TITLE}_video.txt" \
    --postprocessor "FFmpegVideoConvertor" \
    --postprocessor-args "VideoConvertor:-c:v libx264 -c:a aac"

  echo "✅ MP4 téléchargé dans: video/$SAFE_TITLE"
else
  yt-dlp \
    --ignore-errors --no-warnings \
    -f "bestaudio" \
    --extract-audio --audio-format mp3 --audio-quality 160K \
    -o "audio/$SAFE_TITLE/%(title)s.%(ext)s" \
    --yes-playlist "$URL" \
    --download-archive "audio/$SAFE_TITLE/downloaded_${SAFE_TITLE}_audio.txt"

  echo "✅ MP3 téléchargé dans: audio/$SAFE_TITLE"
fi

