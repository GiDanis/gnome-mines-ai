/*
 * Copyright (C) 2026 GNOME Mines AI Contributors
 */

using Gtk;
using Adw;

/**
 * Dialog for viewing AI benchmark leaderboard
 */
public class AiBenchmarkDialog : Adw.Dialog {
    private AiBenchmark benchmark;
    private Gtk.ListBox runs_list;
    private Gtk.DropDown model_filter;
    private Gtk.DropDown difficulty_filter;
    private Gtk.Label stats_label;
    private Adw.Dialog parent_dialog;
    
    public AiBenchmarkDialog(Gtk.Window parent) {
        Object(
            title: _("AI Benchmark Leaderboard"),
            content_width: 800,
            content_height: 600
        );
        
        this.benchmark = AiBenchmark.get_instance();
        this.parent_dialog = this;
        setup_ui();
        load_benchmarks();
    }
    
    private void setup_ui() {
        var main_box = new Gtk.Box(Orientation.VERTICAL, 12);
        main_box.set_margin_start(18);
        main_box.set_margin_end(18);
        main_box.set_margin_top(18);
        main_box.set_margin_bottom(18);
        
        // Filter bar
        var filter_box = new Gtk.Box(Orientation.HORIZONTAL, 12);
        
        var model_label = new Gtk.Label("Model:");
        model_label.set_xalign(0);
        filter_box.append(model_label);
        
        model_filter = new Gtk.DropDown(null, null);
        model_filter.set_hexpand(true);
        model_filter.notify["selected"].connect(() => load_benchmarks());
        filter_box.append(model_filter);
        
        var diff_label = new Gtk.Label("Difficulty:");
        diff_label.set_xalign(0);
        filter_box.append(diff_label);
        
        difficulty_filter = new Gtk.DropDown(null, null);
        difficulty_filter.set_hexpand(true);
        difficulty_filter.notify["selected"].connect(() => load_benchmarks());
        filter_box.append(difficulty_filter);
        
        var reset_button = new Gtk.Button.with_label("Reset");
        reset_button.clicked.connect(() => {
            model_filter.set_selected(0);
            difficulty_filter.set_selected(0);
            load_benchmarks();
        });
        filter_box.append(reset_button);
        
        main_box.append(filter_box);
        
        // Stats summary
        stats_label = new Gtk.Label("");
        stats_label.add_css_class("caption");
        stats_label.set_xalign(0);
        main_box.append(stats_label);
        
        // Scrollable list
        var scroll = new Gtk.ScrolledWindow();
        scroll.set_vexpand(true);
        scroll.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        
        runs_list = new Gtk.ListBox();
        runs_list.add_css_class("boxed-list");
        runs_list.set_activate_on_single_click(false);
        
        scroll.set_child(runs_list);
        main_box.append(scroll);
        
        // Export button
        var export_box = new Gtk.Box(Orientation.HORIZONTAL, 12);
        
        var export_button = new Gtk.Button.with_label("Export CSV");
        export_button.add_css_class("suggested-action");
        export_button.clicked.connect(on_export_clicked);
        export_box.append(export_button);
        
        var clear_button = new Gtk.Button.with_label("Clear All");
        clear_button.add_css_class("destructive-action");
        clear_button.clicked.connect(on_clear_clicked);
        export_box.append(clear_button);
        
        var close_button = new Gtk.Button.with_label("Close");
        close_button.add_css_class("suggested-action");
        close_button.clicked.connect(() => {
            parent_dialog.close();
        });
        export_box.append(close_button);
        
        main_box.append(export_box);
        
        set_child(main_box);
        
        // Setup filter options
        setup_filters();
    }
    
    private void setup_filters() {
        // Model filter
        var models = new Gee.ArrayList<string>();
        models.add("All Models");
        
        var runs = benchmark.get_runs();
        foreach (var run in runs) {
            if (run != null && !models.contains(run.model)) {
                models.add(run.model);
            }
        }
        
        var model_list = new Gtk.StringList(null);
        foreach (var model in models) {
            model_list.append(model);
        }
        model_filter.set_model(model_list);
        
        // Difficulty filter
        var difficulties = new Gee.ArrayList<string>();
        difficulties.add("All Difficulties");
        difficulties.add("easy");
        difficulties.add("medium");
        difficulties.add("hard");
        difficulties.add("custom");
        
        var diff_list = new Gtk.StringList(null);
        foreach (var diff in difficulties) {
            diff_list.append(diff);
        }
        difficulty_filter.set_model(diff_list);
    }
    
    private void load_benchmarks() {
        runs_list.remove_all();
        
        var runs = benchmark.get_runs();
        
        // Apply filters
        string? selected_model = null;
        if (model_filter.get_selected() > 0) {
            var model_item = model_filter.get_model().get_item(model_filter.get_selected()) as Gtk.StringObject;
            if (model_item != null)
                selected_model = model_item.get_string();
        }
        
        string? selected_diff = null;
        if (difficulty_filter.get_selected() > 0) {
            var diff_item = difficulty_filter.get_model().get_item(difficulty_filter.get_selected()) as Gtk.StringObject;
            if (diff_item != null)
                selected_diff = diff_item.get_string();
        }
        
        int wins = 0;
        int total = 0;
        int total_tokens = 0;
        double total_accuracy = 0.0;
        
        foreach (var run in runs) {
            if (run == null) continue;
            
            // Filter by model
            if (selected_model != null && selected_model != "All Models" && !run.model.contains(selected_model))
                continue;
            
            // Filter by difficulty
            if (selected_diff != null && selected_diff != "All Difficulties" && run.difficulty != selected_diff)
                continue;
            
            // Update stats
            total++;
            if (run.win) wins++;
            total_tokens += run.tokens_total;
            total_accuracy += run.accuracy;
            
            // Create row
            var row = new Adw.ActionRow();
            row.set_title("%s %s".printf(
                run.win ? "✅" : "❌",
                run.model
            ));
            
            var subtitle = "%s | %dx%d %d mines | Accuracy: %.1f%% | Tokens: %d | Calls: %d | Time: %d:%02d".printf(
                run.timestamp.replace("T", " ").substring(0, 16),
                run.board_width,
                run.board_height,
                run.mines,
                run.accuracy * 100,
                run.tokens_total,
                run.api_calls,
                run.game_duration_sec / 60,
                run.game_duration_sec % 60
            );
            row.set_subtitle(subtitle);
            
            runs_list.append(row);
        }
        
        // Update stats label
        if (total > 0) {
            double avg_accuracy = total_accuracy / total;
            int avg_tokens = total_tokens / total;
            stats_label.set_label(
                "Total: %d games | Wins: %d (%.1f%%) | Avg Accuracy: %.1f%% | Avg Tokens: %d".printf(
                    total, wins, (double)wins/total*100, avg_accuracy*100, avg_tokens
                )
            );
        } else {
            stats_label.set_label("No benchmark runs found. Play a game with AI enabled to create benchmarks.");
        }
    }
    
    private void on_export_clicked() {
        var filter = new Gtk.FileFilter();
        filter.set_filter_name("CSV files");
        filter.add_pattern("*.csv");
        
        var dialog = new Gtk.FileChooserNative(
            "Export Benchmarks",
            get_parent() as Gtk.Window,
            Gtk.FileChooserAction.SAVE,
            "Save",
            "Cancel"
        );
        dialog.add_filter(filter);
        dialog.set_current_name("gnome-mines-benchmarks.csv");
        
        dialog.response.connect((response_id) => {
            if (response_id == Gtk.ResponseType.ACCEPT) {
                var file = dialog.get_file();
                if (file != null) {
                    benchmark.export_csv(file.get_path());
                }
            }
        });
        
        dialog.show();
    }
    
    private void on_clear_clicked() {
        var dialog = new Adw.AlertDialog(
            "Clear All Benchmarks?",
            "This will delete all benchmark data. This action cannot be undone."
        );
        dialog.add_responses("cancel", "_Cancel", "clear", "_Clear All");
        dialog.set_response_appearance("clear", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("cancel");
        
        dialog.response.connect((_dialog, response) => {
            if (response == "clear") {
                benchmark.clear();
                load_benchmarks();
                setup_filters();
            }
        });
        
        dialog.present(this);
    }
}
