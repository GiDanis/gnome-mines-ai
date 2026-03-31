/*
 * Copyright (C) 2026 GNOME Mines AI Contributors
 */

using Gee;
using GLib;

/**
 * Generates prompts for the AI based on the current game state
 */
public class AiPromptGenerator : GLib.Object
{
    private Minefield minefield;
    private bool ultra_compact = false;
    
    public AiPromptGenerator(Minefield minefield, bool ultra_compact = false)
    {
        this.minefield = minefield;
        this.ultra_compact = ultra_compact;
    }
    
    public void set_ultra_compact(bool compact)
    {
        this.ultra_compact = compact;
    }
    
    /**
     * Generate prompt for AI
     */
    public string generate_prompt()
    {
        if (ultra_compact)
            return generate_ultra_compact_prompt();
        else
            return generate_full_prompt();
    }
    
    /**
     * ULTRA COMPACT prompt (~300 chars vs ~1000)
     * Much faster for slow models
     */
    private string generate_ultra_compact_prompt()
    {
        var sb = new StringBuilder();
        
        // Minimal header
        sb.append_printf("Mines %dx%d, %d left\n", 
            (int) minefield.width, (int) minefield.height,
            (int) (minefield.n_mines - minefield.n_flags));
        
        // Only numbered cells with hidden neighbors
        int[] dx = {-1, 0, 1, -1, 1, -1, 0, 1};
        int[] dy = {-1, -1, -1, 0, 0, 1, 1, 1};
        
        for (uint y = 0; y < minefield.height && y < 10; y++)
        {
            for (uint x = 0; x < minefield.width && x < 10; x++)
            {
                if (!minefield.is_cleared(x, y))
                    continue;
                
                var adj = (int) minefield.get_n_adjacent_mines(x, y);
                if (adj == 0)
                    continue;
                
                // Count hidden/flagged
                int hidden = 0, flagged = 0;
                for (int i = 0; i < 8; i++)
                {
                    int nx = (int)x + dx[i];
                    int ny = (int)y + dy[i];
                    if (nx >= 0 && ny >= 0 && nx < (int)minefield.width && ny < (int)minefield.height)
                    {
                        if (minefield.get_flag((uint)nx, (uint)ny) == FlagType.FLAG)
                            flagged++;
                        else if (!minefield.is_cleared((uint)nx, (uint)ny))
                            hidden++;
                    }
                }

                if (hidden > 0)
                    sb.append_printf("%d@%d,%d:H%dF%d ", adj, (int)x, (int)y, hidden, flagged);
            }
        }
        
        sb.append("\nJSON:{\"action\":\"click|flag\",\"x\":int,\"y\":int}");
        
        return sb.str;
    }
    
    /**
     * Full prompt with complete board state (~1000 chars)
     */
    private string generate_full_prompt()
    {
        var sb = new StringBuilder();
        
        sb.append_printf("MINESWEEPER %dx%d - WIN CONDITION\n", 
            (int) minefield.width, (int) minefield.height);
        sb.append_printf("TOTAL MINES: %d (you must find ALL of them)\n", (int) minefield.n_mines);
        sb.append_printf("MAX FLAGS: %d (exactly enough for all mines)\n", (int) minefield.n_mines);
        sb.append_printf("CURRENT: Flags Used: %d | Mines Remaining: %d\n\n",
            (int) minefield.n_flags, (int) (minefield.n_mines - minefield.n_flags));
        sb.append_printf("GOAL: Flag all %d mines, then click all safe cells. ZERO explosions!\n\n",
            (int) minefield.n_mines);
        
        // Full board grid
        sb.append("BOARD STATE (x=col, y=row, 0-based):\n");
        sb.append("Legend: ?=hidden, F=flag, .=empty, 0-8=number\n\n");
        
        // Compact board representation
        for (uint y = 0; y < minefield.height; y++)
        {
            for (uint x = 0; x < minefield.width; x++)
            {
                if (!minefield.is_cleared(x, y))
                {
                    var flag = minefield.get_flag(x, y);
                    sb.append_c(flag == FlagType.FLAG ? 'F' : '?');
                }
                else
                {
                    var adj = (int) minefield.get_n_adjacent_mines(x, y);
                    sb.append_c(adj == 0 ? '.' : (char)('0' + adj));
                }
            }
            sb.append_c('\n');
        }
        
        sb.append("\nRULE A: If flagged==number, click hidden neighbors\n");
        sb.append("RULE B: If hidden==number-flagged, flag them\n");
        sb.append("\nReply JSON: [{\"action\":\"click|flag\",\"x\":int,\"y\":int,\"reasoning\":\"text\"}]");
        
        return sb.str;
    }
}
