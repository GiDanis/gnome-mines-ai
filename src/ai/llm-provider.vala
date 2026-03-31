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
 * Represents a move decision from the AI
 */
public struct AiMove
{
    public string action;  // "click" or "flag"
    public int x;
    public int y;
    public string comment;
    
    public AiMove(string action, int x, int y, string comment)
    {
        this.action = action;
        this.x = x;
        this.y = y;
        this.comment = comment;
    }
}

/**
 * Abstract base class for LLM providers
 */
public abstract class LlmProvider : GLib.Object
{
    protected string api_key;
    protected string endpoint;
    protected string model;
    
    public signal void response_ready(AiMove move);
    public signal void error_occurred(string message);
    public signal void batch_response_ready(string json_content);
    
    protected LlmProvider(string api_key, string endpoint, string model)
    {
        this.api_key = api_key;
        this.endpoint = endpoint;
        this.model = model;
    }
    
    public abstract void request_move(string prompt);

    protected async string http_post(string url, string content_type, string body) throws Error
    {
        var logger = AiDebugLogger.get_instance();
        logger.logf("HTTP", "POST %s", url);
        logger.logf("HTTP", "Request body (first 200 chars): %s", body.length > 200 ? body.substring(0, 200) + "..." : body);
        
        var session = new Soup.Session();
        var message = new Soup.Message("POST", url);
        message.request_headers.append("Content-Type", content_type);
        message.request_headers.append("Authorization", "Bearer %s".printf(api_key));

        message.set_request_body_from_bytes("application/json", new GLib.Bytes(body.data));

        var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
        
        logger.logf("HTTP", "Response status: %d", (int) message.status_code);

        if (message.status_code != 200)
        {
            var response = (string) bytes.get_data();
            logger.logf("HTTP", "Error response: %s", response.length > 500 ? response.substring(0, 500) + "..." : response);
            throw new IOError.FAILED("HTTP %d: %s", (int) message.status_code, response);
        }

        var result = (string) bytes.get_data();
        logger.logf("HTTP", "Response (first 500 chars): %s", result.length > 500 ? result.substring(0, 500) + "..." : result);
        return result;
    }
}

/**
 * OpenAI-compatible API provider
 */
public class OpenAiProvider : LlmProvider
{
    public OpenAiProvider(string api_key, string endpoint = "https://api.openai.com/v1", string model = "gpt-4o-mini")
    {
        base(api_key, endpoint, model);
    }
    
    public override void request_move(string prompt)
    {
        request_move_async(prompt);
    }
    
    private async void request_move_async(string prompt)
    {
        try
        {
            var request_obj = new Json.Object();
            request_obj.set_string_member("model", model);
            request_obj.set_string_member("temperature", "0.3");
            
            var messages_array = new Json.Array();
            
            // System message
            var system_obj = new Json.Object();
            system_obj.set_string_member("role", "system");
            system_obj.set_string_member("content", 
                "Sei un esperto giocatore di Minesweeper. Analizza il campo di gioco e decidi la mossa ottimale. " +
                "Rispondi SOLO con un JSON valido in questo formato: " +
                "{\"action\": \"click\" o \"flag\", \"x\": numero, \"y\": numero, \"comment\": \"breve commento in italiano\"}. " +
                "Le coordinate x e y partono da 0 in alto a sinistra.");
            
            messages_array.add_object_element(system_obj);
            
            // User message
            var user_obj = new Json.Object();
            user_obj.set_string_member("role", "user");
            user_obj.set_string_member("content", prompt);
            messages_array.add_object_element(user_obj);
            
            request_obj.set_array_member("messages", messages_array);

            var generator = new Json.Generator();
            generator.pretty = false;
            var root = new Json.Node(Json.NodeType.OBJECT);
            root.set_object(request_obj);
            size_t length;
            string body = generator.to_data(out length);

            string response;
            try
            {
                response = yield http_post(
                    "%s/chat/completions".printf(endpoint),
                    "application/json",
                    body
                );
            }
            catch (Error e)
            {
                error_occurred("Errore API: %s".printf(e.message));
                return;
            }
            
            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root_obj = parser.get_root().get_object();
            var choices = root_obj.get_array_member("choices");
            
            if (choices.get_length() == 0)
            {
                error_occurred("Nessuna risposta dall'API");
                return;
            }
            
            var choice = choices.get_object_element(0);
            var message = choice.get_object_member("message");
            var content = message.get_string_member("content");
            
            // Parse the JSON response from the LLM
            var move_parser = new Json.Parser();
            try
            {
                move_parser.load_from_data(content);
            }
            catch (Error e)
            {
                error_occurred("Risposta non valida: %s".printf(e.message));
                return;
            }
            
            var move_obj = move_parser.get_root().get_object();
            
            var move = AiMove(
                move_obj.get_string_member("action"),
                (int) move_obj.get_int_member("x"),
                (int) move_obj.get_int_member("y"),
                move_obj.get_string_member("comment")
            );
            
            response_ready(move);
        }
        catch (Error e)
        {
            error_occurred("Errore: %s".printf(e.message));
        }
    }
}

/**
 * Provider per Ollama (LLM locale)
 */
public class OllamaProvider : LlmProvider
{
    public OllamaProvider(string endpoint = "http://localhost:11434", string model = "llama3.2")
    {
        base("", endpoint, model);  // Ollama non richiede API key di default
    }
    
    public override void request_move(string prompt)
    {
        request_move_async(prompt);
    }
    
    private async void request_move_async(string prompt)
    {
        try
        {
            var logger = AiDebugLogger.get_instance();
            
            // Ensure endpoint has default value for Ollama
            string effective_endpoint = endpoint;
            if (effective_endpoint == null || effective_endpoint == "")
            {
                effective_endpoint = "http://localhost:11434";
            }
            
            logger.logf("OllamaProvider", "Starting request_move_async with prompt length: %d", prompt.length);
            logger.logf("OllamaProvider", "Using endpoint: %s", effective_endpoint);
            logger.logf("OllamaProvider", "Using model: %s", model);
            
            var request_obj = new Json.Object();
            request_obj.set_string_member("model", model);
            request_obj.set_string_member("prompt", prompt);
            request_obj.set_boolean_member("stream", false);
            request_obj.set_string_member("format", "json");

            // Debug: verify request_obj is valid
            logger.logf("OllamaProvider", "Request object created with model=%s, prompt_length=%d", 
                model, prompt.length);

            var generator = new Json.Generator();
            generator.pretty = false;
            var root = new Json.Node(Json.NodeType.OBJECT);
            root.set_object(request_obj);
            
            // Use GLib.stringify for reliability
            string body = Json.to_string(root, false);
            
            logger.logf("OllamaProvider", "Generated JSON body length: %d", body.length);
            logger.logf("OllamaProvider", "Body: %s", body.length > 200 ? body.substring(0, 200) + "..." : body);
            
            // Ensure body is not empty
            if (body.length == 0)
            {
                error_occurred("Errore Ollama: JSON body vuoto");
                return;
            }

            string response;
            try
            {
                logger.logf("OllamaProvider", "Sending HTTP POST to %s/api/generate", effective_endpoint);
                
                var session = new Soup.Session();
                // Increase timeout for slow models (default is 60s)
                session.set_property("timeout", 300); // 5 minutes
                
                var message = new Soup.Message("POST", "%s/api/generate".printf(effective_endpoint));
                message.request_headers.append("Content-Type", "application/json");
                // Ollama doesn't need Authorization header
                
                // Create request body
                var body_bytes = new GLib.Bytes(body.data);
                logger.logf("OllamaProvider", "Request body size: %d bytes", body_bytes.get_size());
                
                message.set_request_body_from_bytes("application/json", body_bytes);

                logger.logf("OllamaProvider", "Sending async request (timeout: 300s)...");
                var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
                
                if (bytes == null)
                {
                    error_occurred("Errore Ollama: Nessuna risposta dal server");
                    return;
                }

                logger.logf("OllamaProvider", "Received response, status: %d", (int) message.status_code);

                if (message.status_code != 200)
                {
                    var error_response = (string) bytes.get_data();
                    error_occurred("Errore Ollama: HTTP %d - %s".printf((int) message.status_code, error_response.length > 200 ? error_response.substring(0, 200) + "..." : error_response));
                    return;
                }

                response = (string) bytes.get_data();
                logger.logf("OllamaProvider", "Response length: %d chars", response.length);
                logger.logf("OllamaProvider", "Response: %s", response.length > 200 ? response.substring(0, 200) + "..." : response);
            }
            catch (Error e)
            {
                logger.logf("OllamaProvider", "HTTP error: %s", e.message);
                error_occurred("Errore Ollama: %s".printf(e.message));
                return;
            }

            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root_obj = parser.get_root().get_object();
            
            // Extract thinking/reasoning if available (some Ollama models provide this)
            string? thinking_content = null;
            if (root_obj.has_member("thinking"))
            {
                thinking_content = root_obj.get_string_member("thinking");
                logger.logf("OllamaProvider", "Found thinking content: %d chars", thinking_content.length);
            }
            else if (root_obj.has_member("thought"))
            {
                thinking_content = root_obj.get_string_member("thought");
                logger.logf("OllamaProvider", "Found thought content: %d chars", thinking_content.length);
            }
            
            // Get response content - some models put JSON in thinking instead of response
            string content = root_obj.get_string_member("response");
            
            // If response is empty but thinking has JSON, use thinking
            if ((content == null || content.length == 0) && thinking_content != null && thinking_content.length > 0)
            {
                logger.log("OllamaProvider", "Response empty, using thinking content as response");
                content = thinking_content;
            }
            
            // Try to extract JSON from thinking if it's mixed with text
            if (content != null && content.length > 0)
            {
                // Look for JSON pattern in the content
                int json_start = content.index_of("{");
                int json_end = content.last_index_of("}");
                
                if (json_start >= 0 && json_end > json_start)
                {
                    string extracted_json = content.substring(json_start, json_end - json_start + 1);
                    logger.logf("OllamaProvider", "Extracted JSON from content: %s", extracted_json.length > 100 ? extracted_json.substring(0, 100) + "..." : extracted_json);
                    content = extracted_json;
                }
                
                // Validate that extracted content looks like valid JSON (starts with { and has action)
                if (!content.has_prefix("{") || (!content.contains("\"action\"") && !content.contains("'action'")))
                {
                    logger.log("OllamaProvider", "Extracted content doesn't look like valid move JSON, trying to fix");
                    // Try to find action pattern in the text
                    if (content.contains("click") || content.contains("flag"))
                    {
                        // Extract coordinates if present
                        int x = 0, y = 0;
                        
                        // Simple extraction: look for "x":number pattern
                        var x_pos = content.index_of("\"x\"");
                        if (x_pos >= 0)
                        {
                            var num_start = x_pos + 3;
                            while (num_start < content.length && (content[num_start] < '0' || content[num_start] > '9'))
                                num_start++;
                            if (num_start < content.length)
                            {
                                var num_end = num_start;
                                while (num_end < content.length && content[num_end] >= '0' && content[num_end] <= '9')
                                    num_end++;
                                if (num_end > num_start)
                                    int.try_parse(content.substring(num_start, num_end - num_start), out x);
                            }
                        }
                        
                        var y_pos = content.index_of("\"y\"");
                        if (y_pos >= 0)
                        {
                            var num_start = y_pos + 3;
                            while (num_start < content.length && (content[num_start] < '0' || content[num_start] > '9'))
                                num_start++;
                            if (num_start < content.length)
                            {
                                var num_end = num_start;
                                while (num_end < content.length && content[num_end] >= '0' && content[num_end] <= '9')
                                    num_end++;
                                if (num_end > num_start)
                                    int.try_parse(content.substring(num_start, num_end - num_start), out y);
                            }
                        }
                        
                        string action = content.contains("flag") ? "flag" : "click";
                        content = "{\"action\":\"%s\",\"x\":%d,\"y\":%d}".printf(action, x, y);
                        logger.logf("OllamaProvider", "Fixed JSON: %s", content);
                    }
                }
            }

            // Parse the JSON response to extract moves
            var move_parser = new Json.Parser();
            try
            {
                move_parser.load_from_data(content);
            }
            catch (Error e)
            {
                error_occurred("Risposta non valida: %s".printf(e.message));
                return;
            }

            var move_obj = move_parser.get_root().get_object();

            var move = AiMove(
                move_obj.get_string_member("action"),
                (int) move_obj.get_int_member("x"),
                (int) move_obj.get_int_member("y"),
                move_obj.get_string_member("comment")
            );
            
            // Validate coordinates are within board bounds
            if (move.x < 0 || move.x > 50 || move.y < 0 || move.y > 50)
            {
                error_occurred("Coordinate non valide: x=%d, y=%d (fuori dalla griglia)".printf(move.x, move.y));
                return;
            }

            // If we have thinking content, display it in the panel
            if (thinking_content != null && thinking_content.length > 0)
            {
                // Extract just the JSON part for display (remove analysis text)
                string display_thinking = thinking_content;
                int json_start = thinking_content.index_of("{");
                int json_end = thinking_content.last_index_of("}");
                if (json_start >= 0 && json_end > json_start)
                {
                    display_thinking = thinking_content.substring(json_start, json_end - json_start + 1);
                }
                
                // Emit thinking as a special move for display
                var thinking_move = AiMove("think", 0, 0, display_thinking);
                response_ready(thinking_move);
            }

            response_ready(move);
        }
        catch (Error e)
        {
            error_occurred("Errore: %s".printf(e.message));
        }
    }
}

/**
 * OpenRouter provider (https://openrouter.ai) - Free tier available
 */
public class OpenRouterProvider : LlmProvider
{
    public OpenRouterProvider(string api_key, string endpoint = "https://openrouter.ai/api/v1", string model = "meta-llama/llama-3-2-3b-instruct")
    {
        base(api_key, endpoint, model);
    }
    
    public override void request_move(string prompt)
    {
        request_move_async(prompt);
    }
    
    private async void request_move_async(string prompt)
    {
        try
        {
            var request_obj = new Json.Object();
            request_obj.set_string_member("model", model);
            request_obj.set_string_member("temperature", "0.3");
            
            var messages_array = new Json.Array();
            
            var system_obj = new Json.Object();
            system_obj.set_string_member("role", "system");
            system_obj.set_string_member("content", 
                "Sei un esperto giocatore di Minesweeper. Rispondi SOLO con JSON: " +
                "{\"action\": \"click|flag\", \"x\": int, \"y\": int, \"comment\": \"string\"}");
            
            messages_array.add_object_element(system_obj);
            
            var user_obj = new Json.Object();
            user_obj.set_string_member("role", "user");
            user_obj.set_string_member("content", prompt);
            messages_array.add_object_element(user_obj);
            
            request_obj.set_array_member("messages", messages_array);
            
            var generator = new Json.Generator();
            generator.pretty = false;
            var root = new Json.Node(Json.NodeType.OBJECT);
            root.set_object(request_obj);
            size_t length;
            string body = generator.to_data(out length);
            
            string response;
            try
            {
                var session = new Soup.Session();
                var message = new Soup.Message("POST", "%s/chat/completions".printf(endpoint));
                message.request_headers.append("Content-Type", "application/json");
                message.request_headers.append("Authorization", "Bearer %s".printf(api_key));
                message.request_headers.append("HTTP-Referer", "https://github.com/gnome-mines");
                message.request_headers.append("X-Title", "GNOME Mines AI");
                message.set_request_body_from_bytes("application/json", new GLib.Bytes(body.data));
                
                var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
                
                if (message.status_code != 200)
                {
                    error_occurred("Errore OpenRouter: HTTP %d".printf((int) message.status_code));
                    return;
                }
                
                response = (string) bytes.get_data();
            }
            catch (Error e)
            {
                error_occurred("Errore OpenRouter: %s".printf(e.message));
                return;
            }
            
            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root_obj = parser.get_root().get_object();
            var choices = root_obj.get_array_member("choices");
            
            if (choices.get_length() == 0)
            {
                error_occurred("Nessuna risposta da OpenRouter");
                return;
            }
            
            var choice = choices.get_object_element(0);
            var msg = choice.get_object_member("message");
            var content = msg.get_string_member("content");
            
            var move_parser = new Json.Parser();
            try
            {
                move_parser.load_from_data(content);
            }
            catch (Error e)
            {
                error_occurred("Risposta non valida: %s".printf(e.message));
                return;
            }
            
            var move_obj = move_parser.get_root().get_object();
            
            var move = AiMove(
                move_obj.get_string_member("action"),
                (int) move_obj.get_int_member("x"),
                (int) move_obj.get_int_member("y"),
                move_obj.get_string_member("comment")
            );
            
            response_ready(move);
        }
        catch (Error e)
        {
            error_occurred("Errore: %s".printf(e.message));
        }
    }
}

/**
 * Groq provider (https://groq.com) - Free tier with generous limits
 */
public class GroqProvider : LlmProvider
{
    public GroqProvider(string api_key, string endpoint = "https://api.groq.com/openai/v1", string model = "llama-3.1-70b-versatile")
    {
        base(api_key, endpoint, model);
    }

    public override void request_move(string prompt)
    {
        request_move_async(prompt);
    }
    
    /**
     * Build JSON request manually as fallback
     */
    private string build_json_manually(string model, string prompt)
    {
        // Escape special characters in prompt for JSON
        string escaped_prompt = prompt.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t");

        // Get temperature from settings
        bool low_temp = AiSettingsFile.get_instance().get_bool("ai-low-temperature", false);
        double temperature = low_temp ? 0.01 : 0.2;

        // SIMPLE LINE-BASED FORMAT - works with ALL models
        string system_prompt = "You are a Minesweeper logic engine. " +
            "Respond with ONE move per line in this EXACT format:\n" +
            "ACTION,x,y,reasoning\n\n" +
            "Examples:\n" +
            "click,15,8,Center for best odds\n" +
            "flag,11,7,Hidden equals remaining mines\n\n" +
            "RULES:\n" +
            "- ACTION is 'click' or 'flag' (lowercase)\n" +
            "- x,y are integers (0-based coordinates)\n" +
            "- reasoning is brief text (NO commas, use spaces)\n" +
            "- NO JSON, NO quotes, NO brackets, NO markdown\n" +
            "- One move per line\n" +
            "- Return empty response if no certain moves\n\n" +
            "LOGIC:\n" +
            "- RULE A: If flagged_neighbors == cell_number → click hidden neighbors\n" +
            "- RULE B: If hidden_neighbors == cell_number - flagged → flag hidden neighbors\n" +
            "- Only return moves you are 100% CERTAIN about";

        return """{"model":"%s","temperature":%g,"messages":[{"role":"system","content":"%s"},{"role":"user","content":"%s"}]}""".printf(model, temperature, system_prompt.replace("\"", "\\\""), escaped_prompt);
    }

    private async void request_move_async(string prompt)
    {
        try
        {
            var logger = AiDebugLogger.get_instance();
            logger.logf("GroqProvider", "Starting request_move_async with prompt length: %d", prompt.length);
            
            var request_obj = new Json.Object();
            request_obj.set_string_member("model", model);
            request_obj.set_double_member("temperature", 0.3);  // Must be number, not string!
            logger.logf("GroqProvider", "Set model: %s, temperature: 0.3", model);

            var messages_array = new Json.Array();

            var system_obj = new Json.Object();
            system_obj.set_string_member("role", "system");
            system_obj.set_string_member("content",
                "Sei un esperto giocatore di Minesweeper. Rispondi SOLO con JSON: " +
                "{\"action\": \"click|flag\", \"x\": int, \"y\": int, \"comment\": \"string\"}");

            messages_array.add_object_element(system_obj);
            logger.logf("GroqProvider", "Added system message");

            var user_obj = new Json.Object();
            user_obj.set_string_member("role", "user");
            user_obj.set_string_member("content", prompt);
            messages_array.add_object_element(user_obj);
            logger.logf("GroqProvider", "Added user message");

            request_obj.set_array_member("messages", messages_array);
            logger.logf("GroqProvider", "Set messages array");

            // Use alternative JSON serialization approach
            string body;
            try
            {
                var node = new Json.Node(Json.NodeType.OBJECT);
                node.set_object(request_obj);
                
                var generator = new Json.Generator();
                generator.pretty = false;
                generator.root = node;
                
                // Try different approaches to get JSON string
                body = generator.to_data(null);
                
                // If that fails, try manual serialization
                if (body == null || body.length == 0)
                {
                    logger.logf("GroqProvider", "to_data(null) returned empty, trying alternative approach");
                    body = build_json_manually(model, prompt);
                }
            }
            catch (Error e)
            {
                logger.logf("GroqProvider", "JSON generation error: %s, using fallback", e.message);
                body = build_json_manually(model, prompt);
            }
            
            logger.logf("GroqProvider", "Generated JSON body - length: %d", body.length);
            if (body.length < 500)
            {
                logger.logf("GroqProvider", "Body content: %s", body);
            }
            
            // Debug: log the request
            logger.logf("HTTP", "Groq request body length: %d", body.length);
            if (body.length < 500)
            {
                logger.logf("HTTP", "Groq request body: %s", body);
            }

            string response;
            try
            {
                var session = new Soup.Session();
                var message = new Soup.Message("POST", "%s/chat/completions".printf(endpoint));
                message.request_headers.append("Content-Type", "application/json");
                message.request_headers.append("Authorization", "Bearer %s".printf(api_key));
                
                // Ensure body is not empty
                if (body.length == 0)
                {
                    error_occurred("Errore Groq: JSON body vuoto");
                    return;
                }
                
                message.set_request_body_from_bytes("application/json", new GLib.Bytes(body.data));

                var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);

                if (message.status_code != 200)
                {
                    var error_body = (string) bytes.get_data();
                    error_occurred("Errore Groq: HTTP %d - %s".printf((int) message.status_code, error_body.length > 200 ? error_body.substring(0, 200) : error_body));
                    return;
                }

                response = (string) bytes.get_data();
            }
            catch (Error e)
            {
                error_occurred("Errore Groq: %s".printf(e.message));
                return;
            }

            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root_obj = parser.get_root().get_object();
            var choices = root_obj.get_array_member("choices");

            if (choices.get_length() == 0)
            {
                error_occurred("Nessuna risposta da Groq");
                return;
            }

            var choice = choices.get_object_element(0);
            var msg = choice.get_object_member("message");
            var content = msg.get_string_member("content");
            
            logger.logf("GroqProvider", "AI response content: %s", content.length > 200 ? content.substring(0, 200) + "..." : content);

            // Emit batch response for AI manager to parse
            batch_response_ready(content);
        }
        catch (Error e)
        {
            error_occurred("Errore: %s".printf(e.message));
        }
    }
}

/**
 * Together AI provider (https://together.ai) - $25 free credits
 */
public class TogetherProvider : LlmProvider
{
    public TogetherProvider(string api_key, string endpoint = "https://api.together.xyz/v1", string model = "meta-llama/Llama-3.2-3B-Instruct-Turbo")
    {
        base(api_key, endpoint, model);
    }
    
    public override void request_move(string prompt)
    {
        request_move_async(prompt);
    }
    
    private async void request_move_async(string prompt)
    {
        try
        {
            var request_obj = new Json.Object();
            request_obj.set_string_member("model", model);
            request_obj.set_string_member("temperature", "0.3");
            
            var messages_array = new Json.Array();
            
            var system_obj = new Json.Object();
            system_obj.set_string_member("role", "system");
            system_obj.set_string_member("content", 
                "Sei un esperto giocatore di Minesweeper. Rispondi SOLO con JSON: " +
                "{\"action\": \"click|flag\", \"x\": int, \"y\": int, \"comment\": \"string\"}");
            
            messages_array.add_object_element(system_obj);
            
            var user_obj = new Json.Object();
            user_obj.set_string_member("role", "user");
            user_obj.set_string_member("content", prompt);
            messages_array.add_object_element(user_obj);
            
            request_obj.set_array_member("messages", messages_array);
            
            var generator = new Json.Generator();
            generator.pretty = false;
            var root = new Json.Node(Json.NodeType.OBJECT);
            root.set_object(request_obj);
            size_t length;
            string body = generator.to_data(out length);
            
            string response;
            try
            {
                var session = new Soup.Session();
                var message = new Soup.Message("POST", "%s/chat/completions".printf(endpoint));
                message.request_headers.append("Content-Type", "application/json");
                message.request_headers.append("Authorization", "Bearer %s".printf(api_key));
                message.set_request_body_from_bytes("application/json", new GLib.Bytes(body.data));
                
                var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
                
                if (message.status_code != 200)
                {
                    error_occurred("Errore Together: HTTP %d".printf((int) message.status_code));
                    return;
                }
                
                response = (string) bytes.get_data();
            }
            catch (Error e)
            {
                error_occurred("Errore Together: %s".printf(e.message));
                return;
            }
            
            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root_obj = parser.get_root().get_object();
            var choices = root_obj.get_array_member("choices");
            
            if (choices.get_length() == 0)
            {
                error_occurred("Nessuna risposta da Together");
                return;
            }
            
            var choice = choices.get_object_element(0);
            var msg = choice.get_object_member("message");
            var content = msg.get_string_member("content");
            
            var move_parser = new Json.Parser();
            try
            {
                move_parser.load_from_data(content);
            }
            catch (Error e)
            {
                error_occurred("Risposta non valida: %s".printf(e.message));
                return;
            }
            
            var move_obj = move_parser.get_root().get_object();
            
            var move = AiMove(
                move_obj.get_string_member("action"),
                (int) move_obj.get_int_member("x"),
                (int) move_obj.get_int_member("y"),
                move_obj.get_string_member("comment")
            );
            
            response_ready(move);
        }
        catch (Error e)
        {
            error_occurred("Errore: %s".printf(e.message));
        }
    }
}
