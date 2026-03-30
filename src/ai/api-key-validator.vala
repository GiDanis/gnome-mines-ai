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
 * Result of API key validation
 */
public struct ApiValidationResult
{
    public bool valid;
    public string message;
    public string? model_info;
    public string? error_details;
    
    public ApiValidationResult(bool valid, string message, string? model_info = null, string? error_details = null)
    {
        this.valid = valid;
        this.message = message;
        this.model_info = model_info;
        this.error_details = error_details;
    }
}

/**
 * Validates API keys for various LLM providers
 */
public class ApiKeyValidator : GLib.Object
{
    private string provider_type;
    private string api_key;
    private string endpoint;
    
    public signal void validation_complete(ApiValidationResult result);
    
    public ApiKeyValidator(string provider_type, string api_key, string endpoint)
    {
        this.provider_type = provider_type;
        this.api_key = api_key;
        this.endpoint = endpoint;
    }
    
    /**
     * Validate the API key by making a test request
     */
    public void validate()
    {
        validate_async();
    }
    
    private async void validate_async()
    {
        try
        {
            ApiValidationResult result;
            
            switch (provider_type)
            {
                case "openai":
                    result = yield validate_openai();
                    break;
                case "openrouter":
                    result = yield validate_openrouter();
                    break;
                case "groq":
                    result = yield validate_groq();
                    break;
                case "together":
                    result = yield validate_together();
                    break;
                case "ollama":
                    result = yield validate_ollama();
                    break;
                default:
                    result = ApiValidationResult(false, "Provider sconosciuto");
                    break;
            }
            
            validation_complete(result);
        }
        catch (Error e)
        {
            validation_complete(ApiValidationResult(
                false,
                "Errore di connessione: %s".printf(e.message)
            ));
        }
    }
    
    /**
     * Validate OpenAI API key
     */
    private async ApiValidationResult validate_openai()
    {
        var session = new Soup.Session();
        var message = new Soup.Message("GET", "%s/models".printf(endpoint));
        message.request_headers.append("Authorization", "Bearer %s".printf(api_key));
        
        var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
        
        if (message.status_code == 200)
        {
            var response = (string) bytes.get_data();
            var parser = new Json.Parser();
            parser.load_from_data(response);
            
            var root_obj = parser.get_root().get_object();
            var models = root_obj.get_array_member("data");
            
            string model_info = null;
            if (models.get_length() > 0)
            {
                var first_model = models.get_object_element(0);
                model_info = "Modelli disponibili: %d".printf((int) models.get_length());
            }

            return ApiValidationResult(true, "API Key valida!", model_info);
        }
        else if (message.status_code == 401)
        {
            return ApiValidationResult(false, "API Key non valida", null, "Codice errore: 401 Unauthorized");
        }
        else
        {
            var response = (string) bytes.get_data();
            return ApiValidationResult(false, "Errore API", null, "HTTP %d: %s".printf((int) message.status_code, response));
        }
    }
    
    /**
     * Validate OpenRouter API key (free tier available)
     */
    private async ApiValidationResult validate_openrouter()
    {
        var session = new Soup.Session();
        var message = new Soup.Message("GET", "https://openrouter.ai/api/v1/auth/key");
        message.request_headers.append("Authorization", "Bearer %s".printf(api_key));
        
        var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
        
        if (message.status_code == 200)
        {
            var response = (string) bytes.get_data();
            var parser = new Json.Parser();
            parser.load_from_data(response);
            
            var root_obj = parser.get_root().get_object();
            var label = root_obj.get_string_member("label");
            var usage = root_obj.get_object_member("usage");
            var limit = usage.get_string_member("limit");
            
            string info = "Key: %s".printf(label ?? "N/A");
            if (limit != null)
            {
                info += "\nLimite: $%s".printf(limit);
            }
            
            return ApiValidationResult(true, "API Key OpenRouter valida!", info);
        }
        else if (message.status_code == 401)
        {
            return ApiValidationResult(false, "API Key non valida", null, "Codice errore: 401 Unauthorized");
        }
        else
        {
            return ApiValidationResult(false, "Errore API", null, "HTTP %d".printf((int) message.status_code));
        }
    }
    
    /**
     * Validate Groq API key (free tier with rate limits)
     */
    private async ApiValidationResult validate_groq()
    {
        var session = new Soup.Session();
        var message = new Soup.Message("GET", "https://api.groq.com/openai/v1/models");
        message.request_headers.append("Authorization", "Bearer %s".printf(api_key));
        
        var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
        
        if (message.status_code == 200)
        {
            var response = (string) bytes.get_data();
            var parser = new Json.Parser();
            parser.load_from_data(response);
            
            var root_obj = parser.get_root().get_object();
            var models = root_obj.get_array_member("data");
            
            // Build list of available model IDs
            StringBuilder model_list = new StringBuilder();
            int count = 0;
            for (uint i = 0; i < models.get_length() && count < 10; i++)
            {
                var model_obj = models.get_object_element(i);
                var model_id = model_obj.get_string_member("id");
                if (count > 0) model_list.append(", ");
                model_list.append(model_id);
                count++;
            }
            
            string model_info = "Modelli disponibili: %d".printf((int) models.get_length());
            if (models.get_length() > 10)
            {
                model_info += " (primi 10: %s...)".printf(model_list.str);
            }
            else
            {
                model_info += ": %s".printf(model_list.str);
            }
            
            return ApiValidationResult(true, "API Key Groq valida!", model_info);
        }
        else if (message.status_code == 401)
        {
            return ApiValidationResult(false, "API Key non valida", null, "Codice errore: 401 Unauthorized");
        }
        else
        {
            var response = (string) bytes.get_data();
            return ApiValidationResult(false, "Errore API", null, "HTTP %d: %s".printf((int) message.status_code, response.length > 200 ? response.substring(0, 200) : response));
        }
    }
    
    /**
     * Validate Together AI API key ($25 free credits)
     */
    private async ApiValidationResult validate_together()
    {
        var session = new Soup.Session();
        var message = new Soup.Message("GET", "https://api.together.xyz/v1/models");
        message.request_headers.append("Authorization", "Bearer %s".printf(api_key));
        
        var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
        
        if (message.status_code == 200)
        {
            var response = (string) bytes.get_data();
            var parser = new Json.Parser();
            parser.load_from_data(response);
            
            var models = parser.get_root().get_array();
            string model_info = "Modelli disponibili: %d".printf((int) models.get_length());

            return ApiValidationResult(true, "API Key Together valida!", model_info);
        }
        else if (message.status_code == 401)
        {
            return ApiValidationResult(false, "API Key non valida", null, "Codice errore: 401 Unauthorized");
        }
        else
        {
            return ApiValidationResult(false, "Errore API", null, "HTTP %d".printf((int) message.status_code));
        }
    }
    
    /**
     * Validate Ollama local installation
     */
    private async ApiValidationResult validate_ollama()
    {
        var session = new Soup.Session();
        var message = new Soup.Message("GET", "%s/api/tags".printf(endpoint));
        
        var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
        
        if (message.status_code == 200)
        {
            var response = (string) bytes.get_data();
            var parser = new Json.Parser();
            parser.load_from_data(response);
            
            var root_obj = parser.get_root().get_object();
            var models = root_obj.get_array_member("models");

            string model_info = "Modelli locali: %d".printf((int) models.get_length());

            return ApiValidationResult(true, "Ollama rilevato!", model_info);
        }
        else
        {
            return ApiValidationResult(
                false,
                "Ollama non raggiungibile",
                null,
                "Assicurati che Ollama sia in esecuzione su %s".printf(endpoint)
            );
        }
    }
}
