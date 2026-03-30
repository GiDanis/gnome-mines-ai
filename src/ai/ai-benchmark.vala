/*
 * Copyright (C) 2026 GNOME Mines AI Contributors
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

using Json;

/**
 * Represents a single AI benchmark run
 */
public struct AiBenchmarkRun {
    public string timestamp;
    public string model;
    public string provider;
    public string difficulty;
    public int board_width;
    public int board_height;
    public int mines;
    public bool win;
    public int game_duration_sec;
    public int moves_total;
    public int moves_certain;
    public int moves_guessed;
    public double accuracy;
    public int api_calls;
    public int tokens_prompt;
    public int tokens_response;
    public int tokens_total;
    public int avg_ms_per_move;
    
    public AiBenchmarkRun() {
        timestamp = "";
        model = "";
        provider = "";
        difficulty = "";
        board_width = 0;
        board_height = 0;
        mines = 0;
        win = false;
        game_duration_sec = 0;
        moves_total = 0;
        moves_certain = 0;
        moves_guessed = 0;
        accuracy = 0.0;
        api_calls = 0;
        tokens_prompt = 0;
        tokens_response = 0;
        tokens_total = 0;
        avg_ms_per_move = 0;
    }
}

/**
 * Manages AI benchmark tracking and storage
 */
public class AiBenchmark : GLib.Object {
    private static AiBenchmark? instance = null;
    private string benchmark_file;
    private Gee.ArrayList<AiBenchmarkRun?> runs;
    
    private AiBenchmark() {
        // Store in user's home directory
        benchmark_file = GLib.Path.build_filename(
            Environment.get_home_dir(),
            ".gnome-mines-benchmarks.json"
        );
        runs = new Gee.ArrayList<AiBenchmarkRun?>();
        load();
    }
    
    public static AiBenchmark get_instance() {
        if (instance == null) {
            instance = new AiBenchmark();
        }
        return instance;
    }
    
    /**
     * Load existing benchmarks from file
     */
    private void load() {
        if (!FileUtils.test(benchmark_file, FileTest.EXISTS)) {
            return;
        }
        
        try {
            string content;
            FileUtils.get_contents(benchmark_file, out content);
            
            var parser = new Json.Parser();
            parser.load_from_data(content);
            
            var root_obj = parser.get_root().get_object();
            var runs_array = root_obj.get_array_member("runs");
            
            for (uint i = 0; i < runs_array.get_length(); i++) {
                var run_obj = runs_array.get_object_element(i);
                var run = AiBenchmarkRun();
                
                run.timestamp = run_obj.get_string_member("timestamp");
                run.model = run_obj.get_string_member("model");
                run.provider = run_obj.get_string_member("provider");
                run.difficulty = run_obj.get_string_member("difficulty");
                run.board_width = (int) run_obj.get_int_member("board_width");
                run.board_height = (int) run_obj.get_int_member("board_height");
                run.mines = (int) run_obj.get_int_member("mines");
                run.win = run_obj.get_boolean_member("win");
                run.game_duration_sec = (int) run_obj.get_int_member("game_duration_sec");
                run.moves_total = (int) run_obj.get_int_member("moves_total");
                run.moves_certain = (int) run_obj.get_int_member("moves_certain");
                run.moves_guessed = (int) run_obj.get_int_member("moves_guessed");
                run.accuracy = run_obj.get_double_member("accuracy");
                run.api_calls = (int) run_obj.get_int_member("api_calls");
                run.tokens_prompt = (int) run_obj.get_int_member("tokens_prompt");
                run.tokens_response = (int) run_obj.get_int_member("tokens_response");
                run.tokens_total = (int) run_obj.get_int_member("tokens_total");
                run.avg_ms_per_move = (int) run_obj.get_int_member("avg_ms_per_move");
                
                runs.add(run);
            }
            
            GLib.debug("Loaded %d benchmark runs from %s", runs.size, benchmark_file);
        }
        catch (Error e) {
            GLib.warning("Could not load benchmarks: %s", e.message);
        }
    }
    
    /**
     * Save benchmarks to file
     */
    public void save() {
        try {
            var root_obj = new Json.Object();
            var runs_array = new Json.Array();
            
            foreach (var run in runs) {
                var run_obj = new Json.Object();
                run_obj.set_string_member("timestamp", run.timestamp);
                run_obj.set_string_member("model", run.model);
                run_obj.set_string_member("provider", run.provider);
                run_obj.set_string_member("difficulty", run.difficulty);
                run_obj.set_int_member("board_width", run.board_width);
                run_obj.set_int_member("board_height", run.board_height);
                run_obj.set_int_member("mines", run.mines);
                run_obj.set_boolean_member("win", run.win);
                run_obj.set_int_member("game_duration_sec", run.game_duration_sec);
                run_obj.set_int_member("moves_total", run.moves_total);
                run_obj.set_int_member("moves_certain", run.moves_certain);
                run_obj.set_int_member("moves_guessed", run.moves_guessed);
                run_obj.set_double_member("accuracy", run.accuracy);
                run_obj.set_int_member("api_calls", run.api_calls);
                run_obj.set_int_member("tokens_prompt", run.tokens_prompt);
                run_obj.set_int_member("tokens_response", run.tokens_response);
                run_obj.set_int_member("tokens_total", run.tokens_total);
                run_obj.set_int_member("avg_ms_per_move", run.avg_ms_per_move);
                
                runs_array.add_object_element(run_obj);
            }
            
            root_obj.set_array_member("runs", runs_array);
            
            var generator = new Json.Generator();
            generator.pretty = true;
            var root = new Json.Node(Json.NodeType.OBJECT);
            root.set_object(root_obj);
            size_t length;
            string content = generator.to_data(out length);
            
            // Ensure directory exists
            string? dir = GLib.Path.get_dirname(benchmark_file);
            if (dir != null && !FileUtils.test(dir, FileTest.IS_DIR)) {
                DirUtils.create_with_parents(dir, 0755);
            }
            
            FileUtils.set_contents(benchmark_file, content);
            GLib.debug("Saved %d benchmark runs to %s", runs.size, benchmark_file);
        }
        catch (Error e) {
            GLib.warning("Could not save benchmarks: %s", e.message);
        }
    }
    
    /**
     * Add a new benchmark run
     */
    public void add_run(AiBenchmarkRun run) {
        runs.add(run);
        save();
    }
    
    /**
     * Get all benchmark runs
     */
    public Gee.ArrayList<AiBenchmarkRun?> get_runs() {
        return runs;
    }
    
    /**
     * Get runs filtered by model
     */
    public Gee.ArrayList<AiBenchmarkRun?> get_runs_by_model(string model) {
        var filtered = new Gee.ArrayList<AiBenchmarkRun?>();
        foreach (var run in runs) {
            if (run != null && run.model.contains(model)) {
                filtered.add(run);
            }
        }
        return filtered;
    }
    
    /**
     * Get runs filtered by difficulty
     */
    public Gee.ArrayList<AiBenchmarkRun?> get_runs_by_difficulty(string difficulty) {
        var filtered = new Gee.ArrayList<AiBenchmarkRun?>();
        foreach (var run in runs) {
            if (run != null && run.difficulty == difficulty) {
                filtered.add(run);
            }
        }
        return filtered;
    }
    
    /**
     * Get statistics for a specific model
     */
    public AiBenchmarkRun get_stats_for_model(string model) {
        var stats = AiBenchmarkRun();
        int count = 0;
        int wins = 0;
        double total_accuracy = 0.0;
        int total_tokens = 0;
        int total_calls = 0;
        int total_duration = 0;
        
        foreach (var run in runs) {
            if (run.model.contains(model)) {
                count++;
                if (run.win) wins++;
                total_accuracy += run.accuracy;
                total_tokens += run.tokens_total;
                total_calls += run.api_calls;
                total_duration += run.game_duration_sec;
            }
        }
        
        if (count > 0) {
            stats.win = (wins > 0);  // Has at least one win
            stats.accuracy = total_accuracy / count;
            stats.tokens_total = total_tokens / count;
            stats.api_calls = total_calls / count;
            stats.game_duration_sec = total_duration / count;
        }
        
        return stats;
    }
    
    /**
     * Export benchmarks to CSV
     */
    public void export_csv(string filepath) {
        try {
            var sb = new StringBuilder();
            
            // Header
            sb.append("timestamp,model,provider,difficulty,board_size,mines,win,");
            sb.append("duration_sec,moves_total,moves_certain,moves_guessed,accuracy,");
            sb.append("api_calls,tokens_prompt,tokens_response,tokens_total,avg_ms_per_move\n");
            
            // Data rows
            foreach (var run in runs) {
                sb.append_printf("%s,%s,%s,%s,%dx%d,%d,%s,%d,%d,%d,%d,%.3f,%d,%d,%d,%d,%d\n",
                    run.timestamp,
                    run.model,
                    run.provider,
                    run.difficulty,
                    run.board_width,
                    run.board_height,
                    run.mines,
                    run.win ? "true" : "false",
                    run.game_duration_sec,
                    run.moves_total,
                    run.moves_certain,
                    run.moves_guessed,
                    run.accuracy,
                    run.api_calls,
                    run.tokens_prompt,
                    run.tokens_response,
                    run.tokens_total,
                    run.avg_ms_per_move
                );
            }
            
            FileUtils.set_contents(filepath, sb.str);
            GLib.debug("Exported %d benchmarks to CSV: %s", runs.size, filepath);
        }
        catch (Error e) {
            GLib.warning("Could not export CSV: %s", e.message);
        }
    }
    
    /**
     * Clear all benchmarks
     */
    public void clear() {
        runs.clear();
        save();
    }
    
    /**
     * Get benchmark file path
     */
    public string get_file_path() {
        return benchmark_file;
    }
}
