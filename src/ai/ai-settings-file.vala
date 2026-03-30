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
 * Fallback settings storage using JSON file
 * Used when GSettings/dconf is not available
 */
public class AiSettingsFile : GLib.Object
{
    private static AiSettingsFile? instance = null;
    private string config_file;
    private Json.Object config = new Json.Object();
    private bool loaded = false;
    
    private AiSettingsFile()
    {
        // Store in user's home directory
        config_file = GLib.Path.build_filename(Environment.get_home_dir(), ".gnome-mines-ai-config.json");
        load();
    }
    
    public static AiSettingsFile get_instance()
    {
        if (instance == null)
        {
            instance = new AiSettingsFile();
        }
        return instance;
    }
    
    private void load()
    {
        if (FileUtils.test(config_file, FileTest.EXISTS))
        {
            try
            {
                string content;
                FileUtils.get_contents(config_file, out content);
                var parser = new Json.Parser();
                parser.load_from_data(content);
                var root_obj = parser.get_root().get_object();

                // Copy all members (strings and booleans)
                foreach (var member in root_obj.get_members())
                {
                    var node = root_obj.get_member(member);
                    if (node.get_value_type() == typeof(string))
                    {
                        config.set_string_member(member, root_obj.get_string_member(member));
                    }
                    else if (node.get_value_type() == typeof(bool))
                    {
                        config.set_boolean_member(member, root_obj.get_boolean_member(member));
                    }
                }
                loaded = true;
                stderr.printf("[AiSettingsFile] Loaded from %s\n", config_file);
                
                // Debug: print loaded API key (masked)
                string api_key = config.has_member("ai-api-key") ? config.get_string_member("ai-api-key") : "";
                if (api_key.length > 0)
                {
                    stderr.printf("[AiSettingsFile] API key loaded: %s...\n", api_key.substring(0, 8));
                }
                else
                {
                    stderr.printf("[AiSettingsFile] WARNING: No API key found in saved config!\n");
                }
            }
            catch (Error e)
            {
                stderr.printf("[AiSettingsFile] Could not load config: %s\n", e.message);
            }
        }
        else
        {
            stderr.printf("[AiSettingsFile] Config file does not exist, creating defaults\n");
            // Set defaults - using best Groq model for reasoning
            config.set_string_member("ai-provider-type", "groq");
            config.set_string_member("ai-api-endpoint", "https://api.groq.com/openai/v1");
            config.set_string_member("ai-model", "llama-3.3-70b-versatile");  // Best for reasoning
            config.set_string_member("ai-api-key", "");
            // AI optimization settings - all OFF by default
            config.set_boolean_member("ai-use-local-logic", false);
            config.set_boolean_member("ai-use-cache", false);
            config.set_boolean_member("ai-compact-prompt", false);
            config.set_boolean_member("ai-batch-moves", false);
            config.set_boolean_member("ai-low-temperature", false);
            loaded = true;
        }
    }
    
    public void save()
    {
        try
        {
            var generator = new Json.Generator();
            generator.pretty = true;
            var root = new Json.Node(Json.NodeType.OBJECT);
            root.set_object(config);
            size_t length;
            string content = generator.to_data(out length);
            
            // Ensure directory exists
            string? config_dir = GLib.Path.get_dirname(config_file);
            if (config_dir != null && !FileUtils.test(config_dir, FileTest.IS_DIR))
            {
                DirUtils.create_with_parents(config_dir, 0755);
            }
            
            FileUtils.set_contents(config_file, content);
            stderr.printf("[AiSettingsFile] Saved to %s\n", config_file);
        }
        catch (Error e)
        {
            stderr.printf("[AiSettingsFile] Could not save config: %s\n", e.message);
        }
    }
    
    public string get_string(string key)
    {
        if (config.has_member(key))
        {
            return config.get_string_member(key);
        }
        return "";
    }
    
    public void set_string(string key, string value)
    {
        config.set_string_member(key, value);
        save(); // Auto-save on every change
    }
    
    public bool get_bool(string key, bool default_value = true)
    {
        if (config.has_member(key))
        {
            return config.get_boolean_member(key);
        }
        return default_value;
    }
    
    public void set_bool(string key, bool value)
    {
        config.set_boolean_member(key, value);
        save();
    }
    
    public void dump()
    {
        stderr.printf("[AiSettingsFile] Current config:\n");
        foreach (var member in config.get_members())
        {
            string value = config.get_string_member(member);
            if (member.contains("key"))
            {
                value = value.length > 8 ? value.substring(0, 8) + "..." : value;
            }
            stderr.printf("  %s = '%s'\n", member, value);
        }
    }
}
