import re, json

html_path = r"c:\Users\User\Documents\Obsidian\projects\Streamer_app\project\assets\Ahmed_Amer_YouTube.html"

with open(html_path, "r", encoding="utf-8") as f:
    content = f.read()

# YouTube ytInitialData stores renderer objects with "title": {"runs": [{"text": "TITLE"}]} and "videoId": "ID"
video_matches = re.findall(r'"videoId":"([a-zA-Z0-9_-]{11})".*?"title":\{"runs":\[\{"text":"([^"]+)"\}\]', content)

video_list = []
seen = set()

for vid, title in video_matches:
    if vid not in seen and len(title) > 5 and "Shorts" not in title and "YouTube" not in title:
        seen.add(vid)
        video_list.append({"vid": vid, "title": title, "dur": "24:15"})

print(f"Found {len(video_list)} videos:")
for idx, v in enumerate(video_list[:20]):
    print(f"{idx+1}. ID: {v['vid']} | Title: {v['title']}")

# Save to json
with open(r"c:\Users\User\Documents\Obsidian\projects\Streamer_app\project\scratch\extracted_videos.json", "w", encoding="utf-8") as f:
    json.dump(video_list, f, ensure_ascii=False, indent=2)
