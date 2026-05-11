# Connect Four AI with Replay and Adaptive Difficulty

## Overview

This project is a Connect Four game developed using the Godot Engine.  
It integrates artificial intelligence, adaptive difficulty, and replay-based analysis to create both an engaging gameplay experience and an analytical tool.

The system includes multiple AI strategies, a dynamic difficulty controller based on player performance, and a replay system that allows users to review and analyze completed games.

---

## Features

- Human vs AI gameplay
- Multiple AI types:
  - Minimax AI
  - Heuristic AI
  - Random AI
  - Adaptive AI
- Adaptive difficulty system (win-rate based)
- Replay system (step forward/backward, autoplay)
- Move analysis:
  - Mistake labeling
  - Confidence gap
  - Evaluation changes
- Game statistics tracking
- Sound effects and background music
- Settings menu with audio controls

---

## Technologies Used

- Godot Engine (GDScript)
- Python (data analysis and visualization)
- CSV/JSONL logging for game data

---

## How to Run the Project

### Requirements
- Godot Engine (version 4.x recommended)

### Steps

1. Clone or download this repository:

2. Open Godot Engine

3. Click **Import Project**

4. Select the project folder

5. Open the project

6. Run the main scene (GameStart or main game scene)

---

## Controls

- Click a column to place a piece
- Use replay controls to navigate past games
- Use the settings menu to adjust audio

---

## Python Analysis

A Python script is included to analyze gameplay data and generate graphs.

### Run the script:

1. Navigate to the python directory:

### Output:

The script generates graphs such as:
- Rolling win rate
- Game duration
- AI depth over time
- AI computation cost (nodes, pruning)

Graphs are saved in the `graphs/` folder.

---

## Project Structure
