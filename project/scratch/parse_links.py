import re

html_path = r"c:\Users\User\Documents\Obsidian\projects\Streamer_app\project\assets\Ahmed_Amer_YouTube.html"

with open(html_path, "r", encoding="utf-8") as f:
    content = f.read()

# Find all watch?v= links and nearby text
for m in re.finditer(r'href="/watch\?v=([a-zA-Z0-9_-]{11})[^"]*"[^>]*title="([^"]+)"', content):
    print("Link title:", m.group(1), m.group(2))

# Find aria-label or title in tags
for m in re.finditer(r'aria-label="([^"]+) by Ahmed Amer', content):
    print("Aria label:", m.group(1))
