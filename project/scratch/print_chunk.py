import re

html_path = r"c:\Users\User\Documents\Obsidian\projects\Streamer_app\project\assets\Ahmed_Amer_YouTube.html"

with open(html_path, "r", encoding="utf-8") as f:
    content = f.read()

matches = [m.start() for m in re.finditer(r'watch\?v=', content)]
print(f"Found {len(matches)} watch?v= occurrences.")
for idx in matches[:5]:
    print("--- CHUNK ---")
    print(content[idx:idx+300])
