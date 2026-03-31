/*
 * Copyright (C) 2026 GNOME Mines AI Contributors
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

using Gee;

/**
 * Cell coordinates
 */
public struct CellPos {
    public uint x;
    public uint y;
    
    public CellPos(uint x, uint y) {
        this.x = x;
        this.y = y;
    }
}

/**
 * Manages AI gameplay - makes decisions and executes moves
 */
public class AiManager : Object
{
    private Minefield minefield;
    private LlmProvider? provider;
    private AiPromptGenerator prompt_generator;
    private AiSettingsFile settings;
    private AiDebugLogger logger;
    private AiCommentaryOverlay? ai_commentary_overlay;
    private AiBenchmark benchmark_tracker;

    // Optimization features
    private bool use_local_logic;
    private bool use_cache;
    private Gee.HashMap<string, AiMove?> move_cache; // Cache board_hash -> move

    // Benchmark metrics
    private int tokens_prompt = 0;
    private int tokens_response = 0;
    private int api_calls = 0;
    private int moves_total = 0;
    private int moves_certain = 0;
    private int moves_guessed = 0;
    private int64 game_start_time = 0;
    private Gee.ArrayList<int> move_times; // ms per move

    private bool _active = false;
    private bool _thinking = false;
    private uint think_timeout_id = 0;
    
    public signal void commentary_ready(string text, string type);
    public signal void ai_state_changed(bool active, bool thinking);
    
    public bool active 
    { 
        get { return _active; }
        set 
        { 
            if (_active != value)
            {
                _active = value;
                ai_state_changed(_active, _thinking);
            }
        }
    }
    
    public bool thinking 
    { 
        get { return _thinking; }
        private set 
        { 
            if (_thinking != value)
            {
                _thinking = value;
                ai_state_changed(_active, _thinking);
            }
        }
    }
    
    public AiManager(Minefield minefield, GLib.Settings gsettings, AiCommentaryOverlay? overlay = null)
    {
        this.minefield = minefield;
        this.settings = AiSettingsFile.get_instance();
        this.logger = AiDebugLogger.get_instance();
        this.ai_commentary_overlay = overlay;
        this.benchmark_tracker = AiBenchmark.get_instance();
        this.move_times = new Gee.ArrayList<int>();

        // Load optimization settings
        this.use_local_logic = settings.get_bool("ai-use-local-logic", true);
        this.use_cache = settings.get_bool("ai-use-cache", true);
        bool ultra_compact = settings.get_bool("ai-ultra-compact-prompt", false);
        this.move_cache = new Gee.HashMap<string, AiMove?>();

        this.prompt_generator = new AiPromptGenerator(minefield, ultra_compact);  // Always use optimized prompt

        logger.log("AiManager", "Created new AiManager instance");
        logger.logf("AiManager", "Optimizations: local_logic=%s, cache=%s",
            use_local_logic ? "Y" : "N", use_cache ? "Y" : "N");
        settings.dump();
        logger.log_settings(
            settings.get_string("ai-provider-type"),
            settings.get_string("ai-api-key"),
            settings.get_string("ai-api-endpoint"),
            settings.get_string("ai-model")
        );

        // Listen to minefield events
        minefield.cleared.connect(on_game_ended);
        minefield.explode.connect(on_game_ended);
    }
    
    /**
     * Start benchmark tracking for new game
     */
    public void start_benchmark() {
        game_start_time = new GLib.DateTime.now_local().to_unix();
        tokens_prompt = 0;
        tokens_response = 0;
        api_calls = 0;
        moves_total = 0;
        moves_certain = 0;
        moves_guessed = 0;
        move_times.clear();
        logger.log("benchmark", "Started new benchmark tracking");
    }
    
    /**
     * Track API call with token counts
     */
    public void track_api_call(int prompt_tokens, int response_tokens) {
        tokens_prompt += prompt_tokens;
        tokens_response += response_tokens;
        api_calls++;
        logger.logf("benchmark", "API call #%d: prompt=%d, response=%d tokens (total=%d)", 
            api_calls, prompt_tokens, response_tokens, tokens_prompt + tokens_response);
    }
    
    /**
     * Track a move (certain if from logic, guessed if not)
     */
    public void track_move(bool certain, int time_ms = 0) {
        moves_total++;
        if (certain)
            moves_certain++;
        else
            moves_guessed++;
        
        if (time_ms > 0)
            move_times.add(time_ms);
        
        logger.logf("benchmark", "Move #%d: %s (%d ms)", 
            moves_total, certain ? "certain" : "guessed", time_ms);
    }
    
    /**
     * Get current benchmark metrics
     */
    public AiBenchmarkRun get_benchmark_run(bool win) {
        var run = AiBenchmarkRun();
        
        var now = new GLib.DateTime.now_local();
        run.timestamp = now.format("%Y-%m-%dT%H:%M:%S");
        
        run.model = settings.get_string("ai-model");
        run.provider = settings.get_string("ai-provider-type");
        
        // Difficulty based on board size
        if (minefield.width == 8 && minefield.height == 8)
            run.difficulty = "easy";
        else if (minefield.width == 16 && minefield.height == 16)
            run.difficulty = "medium";
        else if (minefield.width == 30 && minefield.height == 16)
            run.difficulty = "hard";
        else
            run.difficulty = "custom";
        
        run.board_width = (int) minefield.width;
        run.board_height = (int) minefield.height;
        run.mines = (int) minefield.n_mines;
        run.win = win;
        
        // Calculate game duration from start time
        if (game_start_time > 0) {
            int64 now_unix = now.to_unix();
            run.game_duration_sec = (int) (now_unix - game_start_time);
        } else {
            run.game_duration_sec = 0;
        }
        
        run.moves_total = moves_total;
        run.moves_certain = moves_certain;
        run.moves_guessed = moves_guessed;
        
        if (moves_total > 0)
            run.accuracy = (double) moves_certain / moves_total;
        else
            run.accuracy = 0.0;
        
        run.api_calls = api_calls;
        run.tokens_prompt = tokens_prompt;
        run.tokens_response = tokens_response;
        run.tokens_total = tokens_prompt + tokens_response;
        
        // Calculate average ms per move
        if (move_times.size > 0) {
            int total_ms = 0;
            foreach (int ms in move_times)
                total_ms += ms;
            run.avg_ms_per_move = total_ms / move_times.size;
        } else if (run.game_duration_sec > 0 && moves_total > 0) {
            run.avg_ms_per_move = (run.game_duration_sec * 1000) / moves_total;
        }
        
        return run;
    }
    
    /**
     * Save benchmark at end of game
     */
    public void save_benchmark(bool win) {
        var run = get_benchmark_run(win);
        benchmark_tracker.add_run(run);
        logger.logf("benchmark", "Saved benchmark: win=%s, accuracy=%.1f%%, tokens=%d",
            win ? "Y" : "N", run.accuracy * 100, run.tokens_total);
    }
    
    /**
     * Initialize the AI provider based on settings
     */
    public void initialize_provider()
    {
        var provider_type = settings.get_string("ai-provider-type");
        var api_key = settings.get_string("ai-api-key");
        var endpoint = settings.get_string("ai-api-endpoint");
        var model = settings.get_string("ai-model");
        
        logger.logf("initialize_provider", "Called");
        logger.log_settings(provider_type, api_key, endpoint, model);

        switch (provider_type)
        {
            case "ollama":
                logger.logf("initialize_provider", "Creating OllamaProvider");
                provider = new OllamaProvider(endpoint, model);
                break;
            case "openrouter":
                logger.logf("initialize_provider", "Creating OpenRouterProvider");
                provider = new OpenRouterProvider(api_key, endpoint, model);
                break;
            case "groq":
                logger.logf("initialize_provider", "Creating GroqProvider");
                provider = new GroqProvider(api_key, endpoint, model);
                break;
            case "together":
                logger.logf("initialize_provider", "Creating TogetherProvider");
                provider = new TogetherProvider(api_key, endpoint, model);
                break;
            case "openai":
                logger.logf("initialize_provider", "Creating OpenAiProvider");
                provider = new OpenAiProvider(api_key, endpoint, model);
                break;
            default:
                logger.logf("initialize_provider", "WARNING: Unknown provider '%s', using OpenAiProvider", provider_type);
                provider = new OpenAiProvider(api_key, endpoint, model);
                break;
        }

        if (provider != null)
        {
            provider.response_ready.connect(on_ai_response);
            provider.batch_response_ready.connect(on_ai_batch_response);
            provider.error_occurred.connect(on_ai_error);
            logger.logf("initialize_provider", "Provider initialized successfully");
        }
        else
        {
            logger.logf("initialize_provider", "ERROR: Provider is null!");
        }
    }
    
    /**
     * Start AI thinking about the next move
     */
    public void think()
    {
        logger.logf("think", "Called - active=%s, thinking=%s, provider=%s", 
                   active ? "true" : "false", thinking ? "true" : (provider == null ? "null" : "ready"));
        
        if (!active || thinking || provider == null)
        {
            logger.logf("think", "Aborted - active=%s, thinking=%s, provider=%s", 
                       active ? "true" : "false", thinking ? "true" : "false", provider == null ? "null" : "ready");
            return;
        }

        if (minefield.exploded || minefield.is_complete)
        {
            logger.logf("think", "Aborted - game ended (exploded=%s, complete=%s)", 
                       minefield.exploded ? "true" : "false", minefield.is_complete ? "true" : "false");
            return;
        }

        // LOCAL LOGIC DISABLED - AI must reason about EVERY move
        // use_local_logic is always false to force AI reasoning
        use_local_logic = false;
        
        if (use_local_logic)
        {
            var local_move = find_local_move();
            if (local_move.action != "")
            {
                logger.logf("think", "Local move found: %s at %d,%d", local_move.action, local_move.x, local_move.y);
                var moves = new Gee.ArrayList<AiMove?>();
                moves.add(local_move);
                execute_moves(moves);
                return;
            }
        }
        
        logger.logf("think", "AI will reason about ALL moves (local logic disabled)");

        // Check cache
        if (use_cache)
        {
            var board_hash = get_board_hash();
            if (move_cache.has_key(board_hash))
            {
                var cached_move = move_cache.get(board_hash);
                if (cached_move != null)
                {
                    logger.logf("think", "Cache hit for board %s", board_hash);
                    var moves = new Gee.ArrayList<AiMove?>();
                    moves.add(cached_move);
                    execute_moves(moves);
                    return;
                }
            }
        }

        thinking = true;
        logger.logf("think", "Scheduling AI move...");

        // Schedule thinking after a short delay
        think_timeout_id = Timeout.add(300, () => {
            var prompt = prompt_generator.generate_prompt();
            logger.logf("think", "Generated prompt (length=%d chars)", prompt.length);
            logger.logf("think", "Calling provider.request_move()");
            
            // Track API call (estimate tokens: ~4 per char)
            int prompt_tokens = prompt.length / 4;
            track_api_call(prompt_tokens, 0);  // Response tokens tracked in callback
            
            provider.request_move(prompt);
            think_timeout_id = 0;
            return Source.REMOVE;
        });
    }
    
    /**
     * Find obvious moves using local logic (no API call needed)
     * Returns AiMove with action="" if no obvious move found
     */
    private AiMove find_local_move()
    {
        // Neighbor offsets
        int[] dx = {-1, 0, 1, -1, 1, -1, 0, 1};
        int[] dy = {-1, -1, -1, 0, 0, 1, 1, 1};
        
        // PASS 1: Look for guaranteed safe moves (flagged == number)
        for (uint y = 0; y < minefield.height; y++)
        {
            for (uint x = 0; x < minefield.width; x++)
            {
                if (!minefield.is_cleared(x, y))
                    continue;
                
                var adj_mines = (int) minefield.get_n_adjacent_mines(x, y);
                if (adj_mines == 0)
                    continue;
                
                int hidden = 0, flagged = 0;
                var hidden_cells = new Gee.ArrayList<CellPos?>();
                
                for (int i = 0; i < 8; i++)
                {
                    int nx = (int)x + dx[i];
                    int ny = (int)y + dy[i];
                    if (nx < 0 || ny < 0 || nx >= (int)minefield.width || ny >= (int)minefield.height)
                        continue;
                    
                    if (minefield.get_flag((uint)nx, (uint)ny) == FlagType.FLAG)
                        flagged++;
                    else if (!minefield.is_cleared((uint)nx, (uint)ny))
                    {
                        hidden++;
                        CellPos pos = {(uint)nx, (uint)ny};
                        hidden_cells.add(pos);
                    }
                }
                
                // Rule: All mines flagged -> click hidden cells (SAFE!)
                if (flagged == adj_mines && hidden > 0)
                {
                    var cell = hidden_cells[0];
                    logger.logf("local_logic", "Found SAFE move at %d,%d (cell %d has %d flags)", 
                               (int)cell.x, (int)cell.y, (int)x, (int)y);
                    return AiMove("click", (int)cell.x, (int)cell.y, "Local: sicuro!");
                }
            }
        }
        
        // PASS 2: Look for guaranteed mines (hidden == number - flagged)
        for (uint y = 0; y < minefield.height; y++)
        {
            for (uint x = 0; x < minefield.width; x++)
            {
                if (!minefield.is_cleared(x, y))
                    continue;
                
                var adj_mines = (int) minefield.get_n_adjacent_mines(x, y);
                if (adj_mines == 0)
                    continue;
                
                int hidden = 0, flagged = 0;
                var hidden_cells = new Gee.ArrayList<CellPos?>();
                
                for (int i = 0; i < 8; i++)
                {
                    int nx = (int)x + dx[i];
                    int ny = (int)y + dy[i];
                    if (nx < 0 || ny < 0 || nx >= (int)minefield.width || ny >= (int)minefield.height)
                        continue;
                    
                    if (minefield.get_flag((uint)nx, (uint)ny) == FlagType.FLAG)
                        flagged++;
                    else if (!minefield.is_cleared((uint)nx, (uint)ny))
                    {
                        hidden++;
                        CellPos pos = {(uint)nx, (uint)ny};
                        hidden_cells.add(pos);
                    }
                }
                
                // Rule: Hidden cells = remaining mines -> flag them
                if (hidden > 0 && hidden == adj_mines - flagged)
                {
                    var cell = hidden_cells[0];
                    logger.logf("local_logic", "Found MINE at %d,%d (cell %d needs %d more)", 
                               (int)cell.x, (int)cell.y, (int)x, (int)(adj_mines - flagged));
                    return AiMove("flag", (int)cell.x, (int)cell.y, "Local: mina!");
                }
            }
        }
        
        return AiMove("", 0, 0, "");
    }
    
    /**
     * Generate a hash of the current board state for caching
     */
    private string get_board_hash()
    {
        var sb = new StringBuilder();
        for (uint y = 0; y < minefield.height && y < 20; y++)
        {
            for (uint x = 0; x < minefield.width && x < 20; x++)
            {
                if (!minefield.is_cleared(x, y))
                    sb.append_c(minefield.get_flag(x, y) == FlagType.FLAG ? 'F' : '?');
                else
                    sb.append_c((char)('0' + minefield.get_n_adjacent_mines(x, y)));
            }
        }
        return sb.str;
    }
    
    /**
     * Execute a BATCH of moves from AI response
     * Filters out invalid moves (too many flags, duplicates, etc.)
     */
    private void execute_moves(Gee.ArrayList<AiMove?> moves)
    {
        if (moves.size == 0)
        {
            // No moves from AI - must guess to continue playing!
            logger.log("execute_moves", "No moves from AI - making educated guess");
            var guess_move = make_educated_guess();
            if (guess_move.action != "")
            {
                execute_single_move_and_continue(guess_move);
            }
            else
            {
                commentary_ready("⚠️ Nessuna mossa possibile", "error");
                thinking = false;
            }
            return;
        }
        
        logger.logf("execute_moves", "Processing batch of %d moves", moves.size);
        
        // Calculate remaining mines and flags
        int mines_remaining = (int)(minefield.n_mines - minefield.n_flags);
        int flags_to_place = 0;
        
        // First pass: count how many flags AI wants to place
        foreach (var move in moves)
        {
            if (move != null && (move.action == "flag" || move.action == "FLAG"))
                flags_to_place++;
        }
        
        // Filter out duplicates and invalid moves
        var valid_moves = new Gee.ArrayList<AiMove?>();
        var seen_coords = new Gee.HashSet<string>();
        int flags_placed = 0;
        
        foreach (var move in moves)
        {
            if (move == null || move.action == "")
                continue;
            
            string coord = "%d,%d".printf(move.x, move.y);
            
            // Skip duplicates
            if (seen_coords.contains(coord))
            {
                logger.logf("execute_moves", "Skipping duplicate: %s", coord);
                continue;
            }
            
            // Skip already cleared cells
            if (minefield.is_cleared((uint)move.x, (uint)move.y))
            {
                logger.logf("execute_moves", "Skipping already cleared: %s", coord);
                continue;
            }
            
            // CRITICAL: Skip flag moves if we've reached max flags
            if (move.action == "flag" || move.action == "FLAG")
            {
                if (flags_placed >= mines_remaining)
                {
                    logger.logf("execute_moves", "Skipping flag - max flags reached: %s", coord);
                    // Convert to click instead if cell is hidden
                    if (!minefield.is_cleared((uint)move.x, (uint)move.y))
                    {
                        logger.logf("execute_moves", "Converting to click: %s", coord);
                        var click_move = AiMove("click", move.x, move.y, "max flags reached, clicking instead");
                        move = click_move;
                    }
                    else
                    {
                        continue;
                    }
                }
                else
                {
                    flags_placed++;
                }
            }
            
            // Skip already flagged cells (for click moves)
            if (move.action == "click" && minefield.get_flag((uint)move.x, (uint)move.y) == FlagType.FLAG)
            {
                logger.logf("execute_moves", "Skipping flagged cell for click: %s", coord);
                continue;
            }
            
            seen_coords.add(coord);
            valid_moves.add(move);
        }
        
        logger.logf("execute_moves", "Filtered to %d valid moves (flags: %d/%d)", 
            valid_moves.size, flags_placed, mines_remaining);
        
        if (valid_moves.size == 0)
        {
            // All moves were filtered - make educated guess
            logger.log("execute_moves", "All moves filtered - making educated guess");
            var guess_move = make_educated_guess();
            if (guess_move.action != "")
            {
                execute_single_move_and_continue(guess_move);
            }
            else
            {
                commentary_ready("⚠️ Nessuna mossa valida", "error");
                thinking = false;
            }
            return;
        }
        
        // Execute all valid moves with small delays
        int move_index = 0;
        
        Timeout.add(100, () => {
            if (move_index >= valid_moves.size || minefield.exploded || minefield.is_complete)
            {
                thinking = false;
                if (active && !minefield.exploded && !minefield.is_complete)
                {
                    // Schedule next AI query after all moves done
                    Timeout.add(500, () => {
                        think();
                        return Source.REMOVE;
                    });
                }
                return Source.REMOVE;
            }
            
            var move = valid_moves[move_index];
            if (move != null && move.action != "")
            {
                execute_single_move(move);
            }
            
            move_index++;
            return Source.CONTINUE;
        });
    }
    
    /**
     * Make an educated guess when no certain moves exist
     * LOCAL LOGIC DISABLED - Only use center/random strategy
     */
    private AiMove make_educated_guess()
    {
        logger.log("make_educated_guess", "Looking for safest guess (local logic disabled)");
        
        // LOCAL LOGIC DISABLED - Skip RULE A/B entirely
        // Only use center/random strategy
        
        // Strategy: Click center-most hidden cell (best odds)
        logger.log("make_educated_guess", "Clicking center area");
        int center_x = (int)minefield.width / 2;
        int center_y = (int)minefield.height / 2;
        int best_dist = 9999;
        int best_x = -1, best_y = -1;
        
        for (uint y = 0; y < minefield.height; y++)
        {
            for (uint x = 0; x < minefield.width; x++)
            {
                if (!minefield.is_cleared(x, y) && minefield.get_flag(x, y) != FlagType.FLAG)
                {
                    int dist = ((int)x - center_x) * ((int)x - center_x) + ((int)y - center_y) * ((int)y - center_y);
                    if (dist < best_dist)
                    {
                        best_dist = dist;
                        best_x = (int)x;
                        best_y = (int)y;
                    }
                }
            }
        }
        
        if (best_x >= 0)
        {
            logger.logf("make_educated_guess", "Guessing center at %d,%d", best_x, best_y);
            return AiMove("click", best_x, best_y, "Best odds: center area");
        }
        
        // Fallback: Any hidden cell
        for (uint y = 0; y < minefield.height; y++)
        {
            for (uint x = 0; x < minefield.width; x++)
            {
                if (!minefield.is_cleared(x, y) && minefield.get_flag(x, y) != FlagType.FLAG)
                {
                    logger.logf("make_educated_guess", "Guessing any cell at %d,%d", x, y);
                    return AiMove("click", (int)x, (int)y, "Only move left");
                }
            }
        }
        
        return AiMove("", 0, 0, "");
    }
    
    /**
     * Execute a single move and schedule next think
     */
    private void execute_single_move_and_continue(AiMove move)
    {
        execute_single_move(move);
        
        // Reset thinking flag immediately
        thinking = false;
        
        // Schedule next think after delay
        Timeout.add(800, () => {
            if (active && !minefield.exploded && !minefield.is_complete)
            {
                logger.log("execute_single_move_and_continue", "Scheduling next think");
                think();
            }
            return Source.REMOVE;
        });
    }
    
    /**
     * Execute a single move
     */
    private void execute_single_move(AiMove move)
    {
        // Handle special "think" action - just display the reasoning
        if (move.action == "think")
        {
            if (move.comment != null && move.comment.length > 0)
            {
                string display = move.comment;
                if (display.length > 300)
                    display = display.substring(0, 300) + "...";
                commentary_ready("🧠 Pensiero AI: " + display.replace("\n", " "), "think");
                
                // Set full reasoning in expanded view
                if (ai_commentary_overlay != null)
                    ai_commentary_overlay.set_reasoning(move.comment);
            }
            return;
        }
        
        // Track this move
        track_move(true, 0);  // Consider all AI moves as "certain"
        
        // Validate the move
        if (move.x < 0 || move.x >= (int)minefield.width ||
            move.y < 0 || move.y >= (int)minefield.height)
        {
            logger.logf("execute_move", "Invalid move: %d,%d out of bounds", move.x, move.y);
            commentary_ready("⚠️ Mossa non valida: %d,%d".printf(move.x, move.y), "error");
            return;
        }

        // Execute the action
        if (move.action == "flag" || move.action == "FLAG")
        {
            if (!minefield.is_cleared((uint)move.x, (uint)move.y))
            {
                minefield.set_flag((uint)move.x, (uint)move.y, FlagType.FLAG);
                string msg = move.comment != "" ? "🚩 " + move.comment : "🚩 mina certa";
                commentary_ready(msg, "flag");
                logger.logf("execute_single_move", "Flag at %d,%d - %s", move.x, move.y, move.comment);
            }
        }
        else if (move.action == "click" || move.action == "CLICK")
        {
            if (!minefield.is_cleared((uint)move.x, (uint)move.y))
            {
                minefield.clear_mine((uint)move.x, (uint)move.y);
                string msg = move.comment != "" ? "💥 " + move.comment : "💥 sicuro";
                commentary_ready(msg, "click");
                logger.logf("execute_single_move", "Click at %d,%d - %s", move.x, move.y, move.comment);
            }
            else
            {
                // Try multi-release (chord)
                minefield.multi_release((uint)move.x, (uint)move.y);
                commentary_ready("🔍 Chord", "click");
            }
        }
    }
    
    private void on_ai_response(AiMove move)
    {
        // This is called for single move responses (backward compat)
        // For batch responses, we use on_ai_response_batch
        var moves = new Gee.ArrayList<AiMove?>();
        moves.add(move);
        execute_moves(moves);
    }
    
    /**
     * Parse line-based format: ACTION,x,y,reasoning
     */
    private void parse_line_based_response(string content, Gee.ArrayList<AiMove?> moves)
    {
        string[] lines = content.split("\n");
        
        foreach (string line in lines)
        {
            string trimmed = line.strip();
            
            // Skip empty lines and comments
            if (trimmed.length == 0 || trimmed.has_prefix("#") || trimmed.has_prefix("//"))
                continue;
            
            // Parse: ACTION,x,y,reasoning
            string[] parts = trimmed.split(",");
            
            if (parts.length >= 3)
            {
                string action = parts[0].strip().down();
                
                // Validate action
                if (action != "click" && action != "flag")
                {
                    logger.logf("parse_line_based", "Skipping invalid action: '%s'", action);
                    continue;
                }
                
                // Parse coordinates
                int x, y;
                try
                {
                    x = int.parse(parts[1].strip());
                    y = int.parse(parts[2].strip());
                }
                catch (Error e)
                {
                    logger.logf("parse_line_based", "Invalid coordinates: %s", trimmed);
                    continue;
                }
                
                // Extract reasoning (everything after x,y)
                string reasoning = "";
                if (parts.length >= 4)
                {
                    var reasoning_parts = parts[3:parts.length];
                    reasoning = string.joinv(",", reasoning_parts).strip();
                    
                    // Clean up quotes
                    if (reasoning.has_prefix("\"") || reasoning.has_prefix("'"))
                        reasoning = reasoning.substring(1);
                    if (reasoning.has_suffix("\"") || reasoning.has_suffix("'"))
                        reasoning = reasoning.substring(0, reasoning.length - 1);
                }
                
                moves.add(AiMove(action, x, y, reasoning));
                logger.logf("parse_line_based", "Parsed move: %s at %d,%d - %s", action, x, y, reasoning);
            }
        }
        
        logger.logf("parse_line_based", "Total moves parsed: %d", moves.size);
    }

    /**
     * Wrapper for batch response (matches signal signature)
     */
    private void on_ai_batch_response(string content)
    {
        on_ai_response_batch(content, null);
    }
    
    /**
     * Handle batch AI response with multiple moves
     * Supports BOTH JSON and LINE-BASED formats for maximum compatibility
     */
    public void on_ai_response_batch(string response_content, string? thinking_content = null)
    {
        var moves = new Gee.ArrayList<AiMove?>();
        int64 response_start = GLib.get_monotonic_time();

        logger.logf("on_ai_response_batch", "Raw response: %s", response_content.length > 200 ? response_content.substring(0, 200) + "..." : response_content);

        try
        {
            string content = response_content.strip();
            string full_reasoning = "";
            
            // Display thinking content if provided (from Ollama)
            if (thinking_content != null && thinking_content.length > 0)
            {
                logger.log("on_ai_response_batch", "Showing thinking content from model");
                
                // Show thinking in sidebar
                string display_thinking = thinking_content.strip();
                if (display_thinking.length > 500)
                    display_thinking = display_thinking.substring(0, 500) + "...";
                
                commentary_ready("🧠 Pensiero AI:\n" + display_thinking.replace("\n", " "), "think");
                
                // Set full reasoning in expanded view
                if (ai_commentary_overlay != null)
                    ai_commentary_overlay.set_reasoning(thinking_content);
            }

            // Step 1: Extract and display <think>...</think> block
            int think_start = content.index_of("<think>");
            int think_end = content.index_of("</think>");
            if (think_start >= 0 && think_end > think_start)
            {
                full_reasoning = content.substring(think_start + 9, think_end - think_start - 9);
                logger.log("on_ai_response_batch", "Extracted <think> reasoning block");

                // Display short version in sidebar
                if (full_reasoning.length > 0)
                {
                    string display = full_reasoning.strip();
                    if (display.length > 250)
                        display = display.substring(0, 250) + "...";
                    commentary_ready("🤔 " + display.replace("\n", " "), "think");

                    // Set full reasoning in expanded view
                    if (ai_commentary_overlay != null)
                        ai_commentary_overlay.set_reasoning(full_reasoning);
                }

                content = content.substring(0, think_start) + content.substring(think_end + 10);
            }

            // Step 2: Remove common prefixes
            content = clean_json_prefix(content);

            // Step 3: Try JSON parsing first (most models use JSON)
            bool parsed = parse_json_response(content, moves);

            if (!parsed || moves.size == 0)
            {
                // Fallback to line-based parsing
                logger.log("on_ai_response_batch", "JSON parsing failed/empty, trying line-based format");
                moves.clear();
                parse_line_based_response(content, moves);
            }

            // Track response tokens (estimate: ~4 chars per token)
            int response_tokens = response_content.length / 4;
            tokens_response += response_tokens;

            // Track response time
            int64 response_time_ms = (GLib.get_monotonic_time() - response_start) / 1000;
            logger.logf("benchmark", "Response time: %d ms, tokens: ~%d", response_time_ms, response_tokens);

            logger.logf("on_ai_response_batch", "Total moves parsed: %d", moves.size);
        }
        catch (Error e)
        {
            logger.logf("on_ai_response_batch", "Parse error: %s", e.message);
            commentary_ready("⚠️ Errore parsing: " + e.message, "error");
            thinking = false;
            return;
        }

        if (moves.size > 0)
        {
            execute_moves(moves);
        }
        else
        {
            logger.log("on_ai_response_batch", "No valid moves found, making educated guess");
            var random_move = make_educated_guess();
            if (random_move.action != "")
            {
                execute_single_move_and_continue(random_move);
            }
            else
            {
                commentary_ready("⚠️ Nessuna mossa trovata", "info");
                thinking = false;
            }
        }
    }
    
    /**
     * Parse JSON format: [{"action":"flag","x":4,"y":2,"reasoning":"..."}]
     * Returns true if successfully parsed at least one move
     */
    private bool parse_json_response(string content, Gee.ArrayList<AiMove?> moves)
    {
        try
        {
            // Find JSON array boundaries
            int start = content.index_of("[");
            int end = content.last_index_of("]");
            
            if (start < 0 || end <= start)
            {
                logger.log("parse_json", "No JSON array found");
                return false;
            }
            
            string json = content.substring(start, end - start + 1);
            logger.logf("parse_json", "Extracted JSON: %s", json.length > 150 ? json.substring(0, 150) + "..." : json);
            
            var parser = new Json.Parser();
            parser.load_from_data(json);
            var root_node = parser.get_root();
            
            if (root_node.get_node_type() != Json.NodeType.ARRAY)
            {
                logger.log("parse_json", "Root is not an array");
                return false;
            }
            
            var moves_array = root_node.get_array();
            
            if (moves_array.get_length() == 0)
            {
                logger.log("parse_json", "Empty moves array");
                return true;  // Valid but empty
            }
            
            for (uint i = 0; i < moves_array.get_length(); i++)
            {
                var move_obj = moves_array.get_object_element(i);
                
                if (!move_obj.has_member("action") || 
                    !move_obj.has_member("x") || 
                    !move_obj.has_member("y"))
                {
                    logger.logf("parse_json", "Move %d missing required fields", i);
                    continue;
                }
                
                string action = move_obj.get_string_member("action").down();
                int x = (int) move_obj.get_int_member("x");
                int y = (int) move_obj.get_int_member("y");
                
                string reasoning = "";
                if (move_obj.has_member("reasoning"))
                    reasoning = move_obj.get_string_member("reasoning");
                else if (move_obj.has_member("reason"))
                    reasoning = move_obj.get_string_member("reason");
                else if (move_obj.has_member("comment"))
                    reasoning = move_obj.get_string_member("comment");
                
                moves.add(AiMove(action, x, y, reasoning));
                logger.logf("parse_json", "Parsed move %d: %s at %d,%d - %s", i, action, x, y, reasoning);
            }
            
            logger.logf("parse_json", "Successfully parsed %d moves from JSON", moves.size);
            return moves.size > 0;
        }
        catch (Error e)
        {
            logger.logf("parse_json", "JSON parse error: %s", e.message);
            return false;
        }
    }
    
    /**
     * Find first hidden cell for random first move
     */
    private AiMove find_random_hidden_cell()
    {
        for (uint y = 0; y < minefield.height; y++)
        {
            for (uint x = 0; x < minefield.width; x++)
            {
                if (!minefield.is_cleared(x, y) && minefield.get_flag(x, y) == FlagType.NONE)
                {
                    logger.logf("find_random", "Found hidden cell at %d,%d", x, y);
                    return AiMove("click", (int)x, (int)y, "prima mossa");
                }
            }
        }
        return AiMove("", 0, 0, "");
    }

    /**
     * Remove common non-JSON prefixes from model output
     */
    private string clean_json_prefix(string input)
    {
        string cleaned = input.strip();
        
        // Remove common prefixes
        string[] prefixes = {
            "Here's the JSON:",
            "Here is the JSON:",
            "JSON output:",
            "Response:",
            "The answer is:",
            "I'll respond with JSON:",
            "```json",
            "```"
        };
        
        foreach (string prefix in prefixes)
        {
            if (cleaned.has_prefix(prefix))
            {
                cleaned = cleaned.substring(prefix.length).strip();
                logger.logf("clean_json_prefix", "Removed prefix: '%s'", prefix);
            }
        }
        
        // Remove markdown code blocks
        if (cleaned.has_prefix("```"))
        {
            int end_backtick = cleaned.index_of("```", 3);
            if (end_backtick > 0)
                cleaned = cleaned.substring(3, end_backtick - 3).strip();
        }
        
        return cleaned;
    }
    
    /**
     * Extract JSON array or object from text
     * Looks for VALID JSON structures only (not [15] but [{"action":...}])
     */
    private string extract_json(string input)
    {
        // Strategy 1: Find array of objects [{"action":...}, {...}]
        int start_arr = input.index_of("[{");
        if (start_arr >= 0)
        {
            // Find matching ]
            int depth = 1;
            int i = start_arr + 2;
            while (i < input.length && depth > 0)
            {
                if (input[i] == '[' || input[i] == '{')
                    depth++;
                else if (input[i] == ']' || input[i] == '}')
                    depth--;
                i++;
            }
            
            if (depth == 0)
            {
                string json = input.substring(start_arr, i - start_arr);
                logger.logf("extract_json", "Found array of objects: %d chars", json.length);
                return json;
            }
        }
        
        // Strategy 2: Find simple array [...] that contains objects
        start_arr = input.index_of("[");
        while (start_arr >= 0)
        {
            int end_arr = input.index_of("]", start_arr);
            if (end_arr > start_arr)
            {
                string candidate = input.substring(start_arr, end_arr - start_arr + 1);
                
                // Validate: must contain at least one { for objects
                if (candidate.index_of("{") > 0)
                {
                    logger.logf("extract_json", "Found valid array: %d chars", candidate.length);
                    return candidate;
                }
            }
            start_arr = input.index_of("[", start_arr + 1);
        }
        
        // Strategy 3: Find object {...}
        int start_obj = input.index_of("{");
        if (start_obj >= 0)
        {
            int end_obj = input.last_index_of("}");
            if (end_obj > start_obj)
            {
                return input.substring(start_obj, end_obj - start_obj + 1);
            }
        }
        
        logger.log("extract_json", "No valid JSON found");
        return "";
    }

    private void on_ai_error(string message)
    {
        logger.logf("on_ai_error", "Called - message: %s", message);
        thinking = false;
        commentary_ready("❌ AI: " + message, "error");
        // Disable AI on error
        active = false;
        logger.logf("on_ai_error", "AI disabled");
    }

    /**
     * Update the minefield reference (called when game restarts)
     */
    public void update_minefield(Minefield new_minefield)
    {
        if (minefield != null)
        {
            minefield.cleared.disconnect(on_game_ended);
            minefield.explode.disconnect(on_game_ended);
        }

        this.minefield = new_minefield;
        this.prompt_generator = new AiPromptGenerator(minefield);

        minefield.cleared.connect(on_game_ended);
        minefield.explode.connect(on_game_ended);
        
        // Start new benchmark tracking
        start_benchmark();
    }
    
    private void on_game_ended()
    {
        if (think_timeout_id != 0)
        {
            Source.remove(think_timeout_id);
            think_timeout_id = 0;
        }

        if (minefield.is_complete)
        {
            commentary_ready("🎉 Partita completata!", "info");
            // Save benchmark for win
            save_benchmark(true);
        }
        else if (minefield.exploded)
        {
            commentary_ready("💥 BOOM! Mina esplosa!", "error");
            // Save benchmark for loss
            save_benchmark(false);
        }
        
        active = false;
    }
    
    /**
     * Stop AI thinking
     */
    public void stop()
    {
        if (think_timeout_id != 0)
        {
            Source.remove(think_timeout_id);
            think_timeout_id = 0;
        }
        thinking = false;
        active = false;
    }
}
