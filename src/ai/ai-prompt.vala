/*
 * Copyright (C) 2026 GNOME Mines AI Contributors
 */

using Gee;
using GLib;

/**
 * Represents an interesting cluster around a numbered cell
 */
public struct Cluster {
    public uint center_x;
    public uint center_y;
    public int number;
    public string description;
    
    public Cluster(uint cx, uint cy, int num, string desc) {
        this.center_x = cx;
        this.center_y = cy;
        this.number = num;
        this.description = desc;
    }
}

public class AiPromptGenerator : GLib.Object
{
    private Minefield minefield;
    
    public AiPromptGenerator(Minefield minefield, bool compact = true)
    {
        this.minefield = minefield;
    }
    
    /**
     * Generate prompt with FULL board visibility in text format
     * AI can see the entire board state for better reasoning
     */
    public string generate_prompt()
    {
        var sb = new StringBuilder();
        
        // Header con obiettivo chiaro
        sb.append_printf("MINESWEEPER %dx%d - WIN CONDITION\n", 
            (int) minefield.width, (int) minefield.height);
        sb.append_printf("TOTAL MINES: %d (you must find ALL of them)\n", (int) minefield.n_mines);
        sb.append_printf("MAX FLAGS: %d (exactly enough for all mines)\n", (int) minefield.n_mines);
        sb.append_printf("CURRENT: Flags Used: %d | Mines Remaining: %d\n",
            (int) minefield.n_flags, (int) (minefield.n_mines - minefield.n_flags));
        sb.append_printf("GOAL: Flag all %d mines, then click all safe cells. ZERO explosions!\n\n",
            (int) minefield.n_mines);
        
        // Check if compact prompt is enabled (relevant cells only)
        // Only use compact for VERY large boards (>40x25) to preserve context
        bool compact = (minefield.width > 40 || minefield.height > 25);
        
        // Also check settings override
        bool settings_compact = AiSettingsFile.get_instance().get_bool("ai-compact-prompt", false);
        if (settings_compact)
            compact = true;
        
        if (compact)
        {
            // Send only relevant cells (numbers + hidden neighbors)
            sb.append("=== RELEVANT CELLS ONLY ===\n");
            sb.append("Format: Cell(x,y)=N means cell at position x,y shows number N\n");
            sb.append("For each cell: Hidden neighbors and Flagged neighbors\n\n");
            
            var clusters = find_interesting_clusters();
            
            if (clusters.size == 0)
            {
                sb.append_printf("HIDDEN CELLS: %d | MINES LEFT: %d\n",
                    count_all_hidden(), (int)(minefield.n_mines - minefield.n_flags));
                sb.append("ACTION: Click any hidden cell. Center has best odds for first move.\n");
            }
            else
            {
                for (int i = 0; i < clusters.size; i++)
                {
                    var cluster = clusters[i];
                    int hidden = count_hidden_neighbors(cluster.center_x, cluster.center_y);
                    int flagged = count_flagged_neighbors(cluster.center_x, cluster.center_y);
                    int remaining = cluster.number - flagged;
                    
                    sb.append_printf("[%d] Cell(%d,%d)=%d | Hidden:%d | Flagged:%d | Remaining:%d\n",
                        i+1, (int)cluster.center_x, (int)cluster.center_y,
                        cluster.number, hidden, flagged, remaining);
                    
                    if (flagged == cluster.number && hidden > 0)
                    {
                        sb.append("    ✓ RULE A: All mines flagged! Click hidden cells.\n");
                    }
                    else if (hidden == remaining && hidden > 0)
                    {
                        sb.append("    ✓ RULE B: Hidden = remaining! Flag hidden cells.\n");
                    }
                }
                
                sb.append_printf("\nSUMMARY: %d cells to analyze\n", clusters.size);
            }
        }
        else
        {
            // Full board in compact text format
            sb.append("=== FULL BOARD STATE ===\n");
            sb.append("Legend: ?=hidden, F=flagged, M=maybe, .=safe empty, 1-8=adjacent mines\n\n");
            
            // Column headers
            sb.append("   ");
            for (uint x = 0; x < minefield.width && x < 10; x++)
                sb.append_printf("%d", (int) x);
            if (minefield.width >= 10)
                for (uint x = 10; x < minefield.width; x++)
                    sb.append_printf("%d", (int) (x % 10));
            sb.append("\n   ");
            for (uint x = 0; x < minefield.width; x++)
                sb.append("-");
            sb.append("\n");
            
            // Board rows
            for (uint y = 0; y < minefield.height; y++)
            {
                sb.append_printf("%2d|", (int) y);
                for (uint x = 0; x < minefield.width; x++)
                {
                    if (!minefield.is_cleared(x, y))
                    {
                        var flag = minefield.get_flag(x, y);
                        if (flag == FlagType.FLAG)
                            sb.append("F");
                        else if (flag == FlagType.MAYBE)
                            sb.append("M");
                        else
                            sb.append("?");
                    }
                    else
                    {
                        var adj = (int) minefield.get_n_adjacent_mines(x, y);
                        if (adj == 0)
                            sb.append(".");
                        else
                            sb.append_printf("%d", adj);
                    }
                }
                sb.append("\n");
            }
            
            // Strategic analysis
            sb.append("\n=== STRATEGIC ANALYSIS ===\n");
            var clusters = find_interesting_clusters();
            
            if (clusters.size == 0)
            {
                sb.append_printf("HIDDEN CELLS: %d | MINES LEFT: %d\n",
                    count_all_hidden(), (int)(minefield.n_mines - minefield.n_flags));
                sb.append("ACTION: Click any hidden cell. Center has best odds for first move.\n");
            }
            else
            {
                sb.append_printf("ANALYZING %d key cells:\n\n", clusters.size);
                
                int certain_mines = 0;
                int certain_safe = 0;
                
                for (int i = 0; i < clusters.size; i++)
                {
                    var cluster = clusters[i];
                    int hidden = count_hidden_neighbors(cluster.center_x, cluster.center_y);
                    int flagged = count_flagged_neighbors(cluster.center_x, cluster.center_y);
                    int remaining = cluster.number - flagged;
                    
                    sb.append_printf("[%d] Cell(%d,%d)=%d | Hidden:%d | Flagged:%d | Remaining:%d\n",
                        i+1, (int)cluster.center_x, (int)cluster.center_y,
                        cluster.number, hidden, flagged, remaining);
                    
                    if (flagged == cluster.number && hidden > 0)
                    {
                        sb.append("    ✓ RULE A: All mines flagged! ");
                        sb.append_printf("Click these SAFE cells: ");
                        print_hidden_coords(sb, cluster.center_x, cluster.center_y);
                        sb.append("\n");
                        certain_safe += hidden;
                    }
                    else if (hidden == remaining && hidden > 0)
                    {
                        sb.append("    ✓ RULE B: Hidden = remaining! ");
                        sb.append_printf("Flag these MINES: ");
                        print_hidden_coords(sb, cluster.center_x, cluster.center_y);
                        sb.append("\n");
                        certain_mines += hidden;
                    }
                    else
                    {
                        sb.append_printf("    → Need more info (hidden=%d, remaining=%d)\n", hidden, remaining);
                    }
                }
                
                sb.append_printf("\nSUMMARY: Found %d certain mines, %d certain safe cells\n", 
                    certain_mines, certain_safe);
            }
        }
        
        // Task instructions
        sb.append("\n=== YOUR TASK ===\n");
        sb.append("1. Study the board above\n");
        sb.append("2. Find ALL certain mines (flag them) and ALL certain safe cells (click them)\n");
        sb.append("3. Use RULE A (flagged==number → click hidden) or RULE B (hidden==remaining → flag)\n");
        sb.append("4. Return ALL moves in one JSON array\n\n");
        
        sb.append("Format: [{\"action\":\"click|flag\",\"x\":int,\"y\":int,\"reasoning\":\"which rule + why\"}]\n");
        sb.append("IMPORTANT: Return ALL certain moves you found. Empty [] only if truly none.\n");
        sb.append("WIN STRATEGY: Flag every mine, click every safe cell. NEVER GUESS!");
        
        return sb.str;
    }
    
    private void print_hidden_coords(StringBuilder sb, uint cx, uint cy)
    {
        var coords = new ArrayList<string>();
        int[] dx = {-1, 0, 1, -1, 1, -1, 0, 1};
        int[] dy = {-1, -1, -1, 0, 0, 1, 1, 1};
        
        for (int i = 0; i < 8; i++)
        {
            int nx = (int)cx + dx[i];
            int ny = (int)cy + dy[i];
            if (nx >= 0 && ny >= 0 && nx < (int)minefield.width && ny < (int)minefield.height)
            {
                if (!minefield.is_cleared((uint)nx, (uint)ny) && 
                    minefield.get_flag((uint)nx, (uint)ny) != FlagType.FLAG)
                    coords.add("(%d,%d)".printf(nx, ny));
            }
        }
        sb.append(string.joinv(",", coords.to_array()));
    }
    
    private int count_all_hidden()
    {
        int count = 0;
        for (uint y = 0; y < minefield.height; y++)
        {
            for (uint x = 0; x < minefield.width; x++)
            {
                if (!minefield.is_cleared(x, y) && minefield.get_flag(x, y) != FlagType.FLAG)
                    count++;
            }
        }
        return count;
    }
    
    private int count_hidden_neighbors(uint cx, uint cy)
    {
        int count = 0;
        int[] dx = {-1, 0, 1, -1, 1, -1, 0, 1};
        int[] dy = {-1, -1, -1, 0, 0, 1, 1, 1};
        
        for (int i = 0; i < 8; i++)
        {
            int nx = (int)cx + dx[i];
            int ny = (int)cy + dy[i];
            if (nx >= 0 && ny >= 0 && nx < (int)minefield.width && ny < (int)minefield.height)
            {
                if (!minefield.is_cleared((uint)nx, (uint)ny) && 
                    minefield.get_flag((uint)nx, (uint)ny) != FlagType.FLAG)
                    count++;
            }
        }
        return count;
    }
    
    private int count_flagged_neighbors(uint cx, uint cy)
    {
        int count = 0;
        int[] dx = {-1, 0, 1, -1, 1, -1, 0, 1};
        int[] dy = {-1, -1, -1, 0, 0, 1, 1, 1};
        
        for (int i = 0; i < 8; i++)
        {
            int nx = (int)cx + dx[i];
            int ny = (int)cy + dy[i];
            if (nx >= 0 && ny >= 0 && nx < (int)minefield.width && ny < (int)minefield.height)
            {
                if (minefield.get_flag((uint)nx, (uint)ny) == FlagType.FLAG)
                    count++;
            }
        }
        return count;
    }
    
    /**
     * Find all numbered cells that have hidden neighbors
     */
    private ArrayList<Cluster?> find_interesting_clusters()
    {
        var clusters = new ArrayList<Cluster?>();
        int[] dx = {-1, 0, 1, -1, 1, -1, 0, 1};
        int[] dy = {-1, -1, -1, 0, 0, 1, 1, 1};
        
        for (uint y = 0; y < minefield.height; y++)
        {
            for (uint x = 0; x < minefield.width; x++)
            {
                if (!minefield.is_cleared(x, y))
                    continue;
                
                var num = (int) minefield.get_n_adjacent_mines(x, y);
                if (num == 0)
                    continue;
                
                // Build neighbor description
                var neighbors = new ArrayList<string>();
                int hidden = 0, flagged = 0;
                
                for (int i = 0; i < 8; i++)
                {
                    int nx = (int)x + dx[i];
                    int ny = (int)y + dy[i];
                    
                    if (nx < 0 || ny < 0 || nx >= (int)minefield.width || ny >= (int)minefield.height)
                        continue;
                    
                    if (minefield.get_flag((uint)nx, (uint)ny) == FlagType.FLAG)
                    {
                        flagged++;
                        neighbors.add("F@%d,%d".printf(nx, ny));
                    }
                    else if (!minefield.is_cleared((uint)nx, (uint)ny))
                    {
                        hidden++;
                        neighbors.add("?@%d,%d".printf(nx, ny));
                    }
                    else
                    {
                        var adj = (int) minefield.get_n_adjacent_mines((uint)nx, (uint)ny);
                        neighbors.add("%d@%d,%d".printf(adj, nx, ny));
                    }
                }
                
                // Only include if there are hidden cells to analyze
                if (hidden > 0)
                {
                    string desc = string.joinv(" ", neighbors.to_array());
                    clusters.add(Cluster(x, y, num, 
                        "hidden=%d flagged=%d neighbors=[%s]".printf(hidden, flagged, desc)));
                }
            }
        }
        
        return clusters;
    }
    
    /**
     * Generate simple full board view (fallback)
     */
    public string generate_full_prompt()
    {
        var sb = new StringBuilder();
        sb.append_printf("Minesweeper %dx%d, %d mines.\nGrid:\n", 
            (int) minefield.width, (int) minefield.height, (int) minefield.n_mines);
        
        for (uint y = 0; y < minefield.height && y < 20; y++)
        {
            sb.append_printf("%2d|", (int)y);
            for (uint x = 0; x < minefield.width && x < 30; x++)
            {
                if (!minefield.is_cleared(x, y))
                {
                    var flag = minefield.get_flag(x, y);
                    sb.append(flag == FlagType.FLAG ? "F" : "?");
                }
                else
                {
                    var adj = (int) minefield.get_n_adjacent_mines(x, y);
                    sb.append(adj == 0 ? "." : "%d".printf(adj));
                }
            }
            sb.append("\n");
        }
        
        sb.append("\nJSON:{\"moves\":[{\"action\":\"click|flag\",\"x\":int,\"y\":int,\"reason\":\"it\"}]}");
        return sb.str;
    }
}
