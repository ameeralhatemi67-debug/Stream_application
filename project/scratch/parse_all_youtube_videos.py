import re, json

html_path = r"c:\Users\User\Documents\Obsidian\projects\Streamer_app\project\assets\Ahmed_Amer_YouTube.html"

with open(html_path, "r", encoding="utf-8") as f:
    content = f.read()

pattern = r'watch\?v=([a-zA-Z0-9_-]{11})[^\"]*\".*?aria-label=\"([^\"]+)\".*?<span class=\"ytAttributedStringHost[^\"]*\"[^>]*>([^<]+)</span>'

matches = re.findall(pattern, content, re.DOTALL)
print("Found matches:", len(matches))

seen = set()
video_list = []

for vid, aria_label, span_title in matches:
    clean_title = span_title.strip()
    if vid not in seen and len(clean_title) > 3 and "Shorts" not in clean_title:
        seen.add(vid)
        video_list.append({
            "vid": vid,
            "title": clean_title,
            "aria_label": aria_label,
            "thumbnail": f"https://img.youtube.com/vi/{vid}/hqdefault.jpg"
        })

print(f"Extracted {len(video_list)} unique videos:")
for idx, v in enumerate(video_list[:15]):
    print(f"{idx+1}. [{v['vid']}] {v['title']} (Thumb: {v['thumbnail']})")

with open(r"c:\Users\User\Documents\Obsidian\projects\Streamer_app\project\scratch\ahmed_amer_videos.json", "w", encoding="utf-8") as f:
    json.dump(video_list, f, ensure_ascii=False, indent=2)
