import csv
import os
from statistics import mean
import matplotlib.pyplot as plt


INPUT_CSV = "/Users/brendanharper/Library/Application Support/Godot/app_userdata/CSC 492/connect_four_logs.jsonl"
OUTPUT_DIR = "graphs"
ROLLING_WINDOW = 5


def ensure_output_dir(path: str) -> None:
    if not os.path.exists(path):
        os.makedirs(path)


def parse_score(result: str) -> float:
    result = result.strip().lower()
    if result == "win":
        return 1.0
    if result == "loss":
        return 0.0
    return 0.5


def rolling_average(values, window):
    output = []
    for i in range(len(values)):
        start = max(0, i - window + 1)
        chunk = values[start:i + 1]
        output.append(mean(chunk))
    return output


def load_data(csv_path: str):
    game_numbers = []
    scores = []
    durations = []
    num_moves = []
    ai_depths = []
    ai_move_times = []
    total_ai_nodes = []
    total_ai_prunes = []

    with open(csv_path, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)

        for i, row in enumerate(reader, start=1):
            game_numbers.append(i)
            scores.append(parse_score(row["result"]))
            durations.append(float(row["duration_seconds"]))
            num_moves.append(float(row["num_moves"]))
            ai_depths.append(float(row["ai_depth"]))
            ai_move_times.append(float(row["avg_ai_move_time_ms"]))
            total_ai_nodes.append(float(row["total_ai_nodes"]))
            total_ai_prunes.append(float(row["total_ai_prunes"]))

    return {
        "game_numbers": game_numbers,
        "scores": scores,
        "durations": durations,
        "num_moves": num_moves,
        "ai_depths": ai_depths,
        "ai_move_times": ai_move_times,
        "total_ai_nodes": total_ai_nodes,
        "total_ai_prunes": total_ai_prunes,
    }


def save_line_plot(x, y, xlabel, ylabel, title, filename, target_line=None):
    plt.figure(figsize=(10, 6))
    plt.plot(x, y, marker="o")
    if target_line is not None:
        plt.axhline(target_line, linestyle="--")
    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    plt.title(title)
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(filename, dpi=200)
    plt.close()


def main():
    if not os.path.exists(INPUT_CSV):
        print(f"Could not find {INPUT_CSV}")
        return

    ensure_output_dir(OUTPUT_DIR)
    data = load_data(INPUT_CSV)

    rolling_win_rate = rolling_average(data["scores"], ROLLING_WINDOW)

    save_line_plot(
        data["game_numbers"],
        rolling_win_rate,
        "Game Number",
        "Rolling Win Rate",
        f"Rolling Win Rate Over Time (Window = {ROLLING_WINDOW})",
        os.path.join(OUTPUT_DIR, "rolling_win_rate.png"),
        target_line=0.5,
    )

    save_line_plot(
        data["game_numbers"],
        data["num_moves"],
        "Game Number",
        "Moves",
        "Game Length Over Time",
        os.path.join(OUTPUT_DIR, "game_length.png"),
    )

    save_line_plot(
        data["game_numbers"],
        data["durations"],
        "Game Number",
        "Duration (seconds)",
        "Game Duration Over Time",
        os.path.join(OUTPUT_DIR, "game_duration.png"),
    )

    save_line_plot(
        data["game_numbers"],
        data["ai_depths"],
        "Game Number",
        "AI Depth",
        "AI Depth Over Time",
        os.path.join(OUTPUT_DIR, "ai_depth.png"),
    )

    save_line_plot(
        data["game_numbers"],
        data["ai_move_times"],
        "Game Number",
        "Average AI Move Time (ms)",
        "Average AI Move Time Over Time",
        os.path.join(OUTPUT_DIR, "ai_move_time.png"),
    )

    save_line_plot(
        data["game_numbers"],
        data["total_ai_nodes"],
        "Game Number",
        "Total AI Nodes",
        "Total AI Nodes Searched Per Game",
        os.path.join(OUTPUT_DIR, "ai_nodes.png"),
    )

    save_line_plot(
        data["game_numbers"],
        data["total_ai_prunes"],
        "Game Number",
        "Total AI Prunes",
        "Total Alpha-Beta Prunes Per Game",
        os.path.join(OUTPUT_DIR, "ai_prunes.png"),
    )

    print(f"Done. Graphs saved in: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
