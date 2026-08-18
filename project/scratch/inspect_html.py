import re

html_path = r"c:\Users\User\Documents\Obsidian\projects\Streamer_app\project\assets\Ahmed_Amer_YouTube.html"

with open(html_path, "r", encoding="utf-8") as f:
    content = f.read()

# Search for videoId followed within 300 chars by text
matches = re.findall(r'"videoId":"([a-zA-Z0-9_-]{11})".{1,400}?"text":"([^"]+)"', content, re.DOTALL)
print("Matches count:", len(matches))
seen = set()
for vid, text in matches:
    if vid not in seen and len(text) > 8 and "YouTube" not in text:
        seen.add(vid)
        print(f"Vid: {vid} | Text: {text}")
