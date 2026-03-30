/*
 * Copyright (C) 2026 GNOME Mines AI Contributors
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

/**
 * Simple debug logger for AI module
 * Writes to /tmp/gnome-mines-ai-debug.log
 */
public class AiDebugLogger : GLib.Object
{
    private static AiDebugLogger? instance = null;
    private FileStream? log_stream = null;
    private string log_file = "/tmp/gnome-mines-ai-debug.log";
    
    private AiDebugLogger()
    {
        // Open log file in append mode
        try
        {
            log_stream = FileStream.open(log_file, "a");
            log_stream.printf("\n========== GNOME Mines AI Debug Log Started: %s ==========\n", 
                             new DateTime.now_local().to_string());
            log_stream.flush();
        }
        catch (FileError e)
        {
            stderr.printf("Could not open log file %s: %s\n", log_file, e.message);
        }
    }
    
    public static AiDebugLogger get_instance()
    {
        if (instance == null)
        {
            instance = new AiDebugLogger();
        }
        return instance;
    }
    
    public void log(string category, string message)
    {
        if (log_stream != null)
        {
            var timestamp = new DateTime.now_local().format("%H:%M:%S");
            log_stream.printf("[%s] [%s] %s\n", timestamp, category, message);
            log_stream.flush();
        }
        // Also print to stderr for real-time debugging
        stderr.printf("[AI-DEBUG] [%s] %s\n", category, message);
    }
    
    public void logf(string category, string format, ...)
    {
        var message = format.vprintf(va_list());
        log(category, message);
    }

    public void log_settings(string provider_type, string api_key, string endpoint, string model)
    {
        string masked_key = api_key.length > 8
                          ? api_key.substring(0, 8) + "..."
                          : api_key;
        logf("SETTINGS", "provider_type='%s', api_key='%s' (len=%d), endpoint='%s', model='%s'",
            provider_type, masked_key, (int) api_key.length, endpoint, model);
    }

    public void log_http_request(string provider, string url, string method)
    {
        logf("HTTP", "%s %s (provider: %s)", method, url, provider);
    }

    public void log_http_response(string provider, int status_code, string? error_body = null)
    {
        string? truncated_body = null;
        if (error_body != null && error_body.length > 200)
        {
            truncated_body = error_body.substring(0, 200) + "...";
        }
        logf("HTTP", "%s response: %d %s", provider, status_code, truncated_body ?? error_body ?? "");
    }

    public void clear()
    {
        if (log_stream != null)
        {
            log_stream.printf("\n========== Log Cleared ==========\n\n");
            log_stream.flush();
        }
    }
}
