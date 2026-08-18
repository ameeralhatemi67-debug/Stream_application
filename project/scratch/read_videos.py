import json

json_path = r"c:\Users\User\Documents\Obsidian\projects\Streamer_app\project\scratch\ahmed_amer_videos.json"

with open(json_path, "r", encoding="utf-8") as f:
    videos = json.load(f)

print(f"Total videos in json: {len(videos)}")
for idx, v in enumerate(videos[:15]):
    print(f"{idx+1}. ID: {v['vid']} | Title: {v['title']}")
