/*
 * Copyright (C) 2026 GNOME Mines AI Contributors
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

using Gtk;
using Adw;

/**
 * Dialog for configuring AI settings with visual feedback and API key validation
 */
public class AiPreferencesDialog : Adw.PreferencesDialog
{
    private AiSettingsFile settings;
    
    private Gtk.ComboBoxText provider_combo;
    private Adw.EntryRow api_key_entry;
    private Adw.EntryRow endpoint_entry;
    private Gtk.ComboBoxText model_combo;
    private Gtk.Image api_key_status_icon;
    private Gtk.Label api_key_status_label;
    private Gtk.Spinner validation_spinner;
    private Gtk.Button validate_button;
    
    // Save status
    private Gtk.Label save_status_label;
    private uint save_status_timeout = 0;
    
    // Validator
    private ApiKeyValidator? validator = null;

    public AiPreferencesDialog(Gtk.Window parent, GLib.Settings gsettings)
    {
        Object(
            title: _("AI Settings")
        );
        
        this.settings = AiSettingsFile.get_instance();
        setup_ui();
        load_settings();
    }
    
    private void setup_ui()
    {
        var ai_page = new Adw.PreferencesPage();
        ai_page.set_title(_("AI Configuration"));
        ai_page.set_icon_name("dialog-information-symbolic");
        
        // Save status banner
        var status_group = new Adw.PreferencesGroup();
        save_status_label = new Gtk.Label("");
        save_status_label.add_css_class("success-label");
        save_status_label.set_visible(false);
        save_status_label.set_margin_top(6);
        save_status_label.set_margin_bottom(6);
        status_group.add(save_status_label);
        ai_page.add(status_group);
        
        // Provider selection group
        var provider_group = new Adw.PreferencesGroup();
        provider_group.set_title(_("Provider"));
        provider_group.set_description(_("Choose the AI provider. Free options available!"));
        
        provider_combo = new Gtk.ComboBoxText();
        provider_combo.append("openai", "OpenAI (GPT-4, GPT-3.5)");
        provider_combo.append("openrouter", "OpenRouter (Free tier - Llama, Mistral)");
        provider_combo.append("groq", "Groq (Free - Fast inference)");
        provider_combo.append("together", "Together AI ($25 free credits)");
        provider_combo.append("ollama", "Ollama (Local LLM - Free)");
        provider_combo.set_active_id(settings.get_string("ai-provider-type"));
        provider_combo.notify["active-id"].connect(() => {
            update_provider_settings();
        });
        
        var provider_row = new Adw.ActionRow();
        provider_row.set_title(_("Provider"));
        provider_row.add_suffix(provider_combo);
        provider_row.set_activatable_widget(provider_combo);
        provider_group.add(provider_row);
        
        ai_page.add(provider_group);
        
        // API Settings group
        var api_group = new Adw.PreferencesGroup();
        api_group.set_title(_("API Settings"));
        api_group.set_description(_("Configure your API credentials"));
        
        // API Key row with validation
        var api_key_box = new Gtk.Box(Orientation.HORIZONTAL, 6);
        api_key_box.set_halign(Gtk.Align.FILL);
        api_key_box.set_hexpand(true);
        
        api_key_entry = new Adw.EntryRow();
        api_key_entry.set_title(_("API Key"));
        api_key_entry.set_show_apply_button(false);  // Auto-save
        api_key_entry.set_hexpand(true);
        
        // Auto-save API key when user types (if looks valid)
        api_key_entry.changed.connect(() => {
            string key = api_key_entry.get_text();
            if (key.length >= 20)  // Only save if looks like a valid key
            {
                settings.set_string("ai-api-key", key);
                settings.save();  // Force save to file!
                api_key_status_icon.set_from_icon_name("object-select-symbolic");
                api_key_status_icon.set_visible(true);
            }
        });

        api_key_entry.apply.connect(() => {
            settings.set_string("ai-api-key", api_key_entry.get_text());
            settings.save();  // Force save to file!
            show_save_status(_("Impostazioni salvate!"));
        });
        api_key_box.append(api_key_entry);
        
        // API Key status icon
        api_key_status_icon = new Gtk.Image.from_icon_name("object-select-symbolic");
        api_key_status_icon.set_pixel_size(16);
        api_key_status_icon.set_visible(false);
        api_key_status_icon.add_css_class("success-icon");
        api_key_box.append(api_key_status_icon);
        
        api_group.add(api_key_box);
        
        // Validation row
        var validate_box = new Gtk.Box(Orientation.HORIZONTAL, 6);
        validate_box.set_margin_start(18);
        validate_box.set_margin_bottom(6);
        
        validate_button = new Gtk.Button.with_label(_("Verifica API Key"));
        validate_button.add_css_class("flat");
        validate_button.clicked.connect(on_validate_clicked);
        validate_box.append(validate_button);
        
        validation_spinner = new Gtk.Spinner();
        validation_spinner.set_size_request(16, 16);
        validation_spinner.set_visible(false);
        validate_box.append(validation_spinner);
        
        api_key_status_label = new Gtk.Label("");
        api_key_status_label.set_xalign(0);
        api_key_status_label.add_css_class("caption");
        api_key_status_label.set_visible(false);
        validate_box.append(api_key_status_label);
        
        api_group.add(validate_box);
        
        // Endpoint
        endpoint_entry = new Adw.EntryRow();
        endpoint_entry.set_title(_("API Endpoint"));
        endpoint_entry.set_show_apply_button(true);
        endpoint_entry.apply.connect(() => {
            settings.set_string("ai-api-endpoint", endpoint_entry.get_text());
            show_save_status(_("Impostazioni salvate!"));
        });
        api_group.add(endpoint_entry);
        
        // Model dropdown with refresh button
        var model_box = new Gtk.Box(Orientation.HORIZONTAL, 6);
        model_box.set_hexpand(true);
        
        model_combo = new Gtk.ComboBoxText();
        model_combo.set_hexpand(true);
        model_combo.notify["active-id"].connect(() => {
            string model_id = model_combo.get_active_id();
            settings.set_string("ai-model", model_id);
            show_save_status(_("Modello salvato!"));
            
            // Update model label in AI sidebar if visible
            // Notify that model changed
            var app = GLib.Application.get_default() as Mines;
            if (app != null)
            {
                app.notify_ai_model_changed(model_id);
            }
        });
        model_box.append(model_combo);
        
        // Groq models will be loaded dynamically when API key is validated
        
        var model_row = new Adw.ActionRow();
        model_row.set_title(_("Model"));
        model_row.set_child(model_box);
        api_group.add(model_row);
        
        ai_page.add(api_group);
        
        // Optimizations group
        var opt_group = new Adw.PreferencesGroup();
        opt_group.set_title(_("AI Optimizations"));
        opt_group.set_description(_("Optional optimizations to reduce API calls. All OFF by default for maximum AI reasoning."));
        
        // Compact Prompt toggle (uses relevant cells only)
        var compact_switch = new Gtk.Switch();
        compact_switch.set_active(settings.get_bool("ai-compact-prompt", false));
        compact_switch.set_valign(Gtk.Align.CENTER);
        compact_switch.notify["active"].connect(() => {
            settings.set_bool("ai-compact-prompt", compact_switch.get_active());
            show_save_status(_("Impostazioni salvate!"));
        });
        var compact_row = new Adw.ActionRow();
        compact_row.set_title(_("Compact Prompt"));
        compact_row.set_subtitle(_("Send only relevant cells. Saves 70% tokens. OFF=full board view"));
        compact_row.add_suffix(compact_switch);
        compact_row.set_activatable_widget(compact_switch);
        opt_group.add(compact_row);
        
        // Local logic toggle
        var local_switch = new Gtk.Switch();
        local_switch.set_active(settings.get_bool("ai-use-local-logic", false));
        local_switch.set_valign(Gtk.Align.CENTER);
        local_switch.notify["active"].connect(() => {
            settings.set_bool("ai-use-local-logic", local_switch.get_active());
            show_save_status(_("Impostazioni salvate!"));
        });
        var local_row = new Adw.ActionRow();
        local_row.set_title(_("Local Logic"));
        local_row.set_subtitle(_("AI skips obvious moves. Saves 80% API calls. OFF=AI decides everything"));
        local_row.add_suffix(local_switch);
        local_row.set_activatable_widget(local_switch);
        opt_group.add(local_row);
        
        // Cache toggle
        var cache_switch = new Gtk.Switch();
        cache_switch.set_active(settings.get_bool("ai-use-cache", false));
        cache_switch.set_valign(Gtk.Align.CENTER);
        cache_switch.notify["active"].connect(() => {
            settings.set_bool("ai-use-cache", cache_switch.get_active());
            show_save_status(_("Impostazioni salvate!"));
        });
        var cache_row = new Adw.ActionRow();
        cache_row.set_title(_("Move Cache"));
        cache_row.set_subtitle(_("Reuse AI responses for same situations. Saves 50% calls. OFF=always ask AI"));
        cache_row.add_suffix(cache_switch);
        cache_row.set_activatable_widget(cache_switch);
        opt_group.add(cache_row);
        
        // Batch moves toggle
        var batch_switch = new Gtk.Switch();
        batch_switch.set_active(settings.get_bool("ai-batch-moves", false));
        batch_switch.set_valign(Gtk.Align.CENTER);
        batch_switch.notify["active"].connect(() => {
            settings.set_bool("ai-batch-moves", batch_switch.get_active());
            show_save_status(_("Impostazioni salvate!"));
        });
        var batch_row = new Adw.ActionRow();
        batch_row.set_title(_("Batch Moves"));
        batch_row.set_subtitle(_("Execute all AI moves at once. Reduces calls 60%. OFF=one by one"));
        batch_row.add_suffix(batch_switch);
        batch_row.set_activatable_widget(batch_switch);
        opt_group.add(batch_row);
        
        // Low temperature toggle
        var temp_switch = new Gtk.Switch();
        temp_switch.set_active(settings.get_bool("ai-low-temperature", false));
        temp_switch.set_valign(Gtk.Align.CENTER);
        temp_switch.notify["active"].connect(() => {
            settings.set_bool("ai-low-temperature", temp_switch.get_active());
            show_save_status(_("Impostazioni salvate!"));
        });
        var temp_row = new Adw.ActionRow();
        temp_row.set_title(_("Low Temperature"));
        temp_row.set_subtitle(_("AI more deterministic (0.01 vs 0.2). OFF=more creative reasoning"));
        temp_row.add_suffix(temp_switch);
        temp_row.set_activatable_widget(temp_switch);
        opt_group.add(temp_row);
        
        ai_page.add(opt_group);

        // Provider info group
        var info_group = new Adw.PreferencesGroup();
        info_group.set_title(_("Provider Information"));
        
        var info_row = new Adw.ActionRow();
        var info_label = new Gtk.Label(null);
        info_label.set_markup(get_provider_info_markup());
        info_label.set_wrap(true);
        info_label.set_xalign(0);
        info_label.set_margin_top(6);
        info_label.set_margin_bottom(6);
        info_row.set_child(info_label);
        info_group.add(info_row);
        
        // Links
        var links_box = new Gtk.Box(Orientation.VERTICAL, 6);
        links_box.set_margin_top(6);
        
        var groq_info = new Gtk.Label(null);
        groq_info.set_markup(
            "<b>Groq Models:</b>\n" +
            "All available models will be loaded automatically when you validate your API key.\n" +
            "Includes: Llama 3, GPT-OSS, Gemma, Qwen, and more.\n");
        groq_info.set_wrap(true);
        groq_info.set_xalign(0);
        groq_info.add_css_class("caption");
        links_box.append(groq_info);
        
        var groq_link = new Gtk.LinkButton.with_label(
            "https://console.groq.com/keys",
            "🔑 Get Groq API Key (free)"
        );
        groq_link.add_css_class("flat");
        links_box.append(groq_link);
        
        var together_link = new Gtk.LinkButton.with_label(
            "https://api.together.ai/settings",
            "🔑 Ottieni API Key Together ($25 gratuiti)"
        );
        together_link.add_css_class("flat");
        links_box.append(together_link);
        
        var openai_link = new Gtk.LinkButton.with_label(
            "https://platform.openai.com/api-keys",
            "🔑 Ottieni API Key OpenAI (a pagamento)"
        );
        openai_link.add_css_class("flat");
        links_box.append(openai_link);
        
        info_group.add(links_box);
        
        ai_page.add(info_group);
        
        add(ai_page);
    }
    
    private string get_provider_info_markup()
    {
        return 
            "<b>Provider Gratuiti:</b>\n" +
            "• <b>OpenRouter:</b> Modelli Llama 3.2, Mistral 7B - ~100 req/giorno\n" +
            "• <b>Groq:</b> Llama 3.1 70B, Mixtral - ~30 req/min (molto veloce!)\n" +
            "• <b>Together AI:</b> Vari modelli Llama/Mistral - $25 crediti iniziali\n" +
            "• <b>Ollama:</b> Esegue in locale - completamente gratuito\n\n" +
            "<b>Provider a Pagamento:</b>\n" +
            "• <b>OpenAI:</b> GPT-4, GPT-3.5 - ~$0.01 per partita\n\n" +
            "<i>Seleziona un provider per vedere i dettagli specifici.</i>";
    }
    
    private void load_settings()
    {
        // Load API key from settings
        string saved_key = settings.get_string("ai-api-key");
        api_key_entry.set_text(saved_key);
        
        // Show checkmark if key exists
        if (saved_key.length > 0)
        {
            api_key_status_icon.set_from_icon_name("object-select-symbolic");
            api_key_status_icon.add_css_class("success-icon");
            api_key_status_icon.set_visible(true);
        }
        
        endpoint_entry.set_text(settings.get_string("ai-api-endpoint"));

        update_provider_settings();

        // Set model after populating combo
        var saved_model = settings.get_string("ai-model");
        if (saved_model != "" && model_combo.get_active_id() != saved_model)
        {
            model_combo.set_active_id(saved_model);
        }
    }
    
    private void update_provider_settings()
    {
        var provider_type = provider_combo.get_active_id();
        
        // Save provider type immediately
        settings.set_string("ai-provider-type", provider_type ?? "groq");
        
        // Clear and populate model combo based on provider
        model_combo.remove_all();
        
        // Update endpoint based on provider
        switch (provider_type)
        {
            case "openai":
                endpoint_entry.set_text("https://api.openai.com/v1");
                add_common_models();
                api_key_entry.set_visible(true);
                validate_button.set_visible(true);
                break;
            case "openrouter":
                endpoint_entry.set_text("https://openrouter.ai/api/v1");
                add_openrouter_models();
                api_key_entry.set_visible(true);
                validate_button.set_visible(true);
                break;
            case "groq":
                endpoint_entry.set_text("https://api.groq.com/openai/v1");
                // Models will be loaded dynamically when API key is validated
                model_combo.remove_all();
                model_combo.append("", "Inserisci API Key e clicca 'Verifica'");
                model_combo.set_active_id("");
                api_key_entry.set_visible(true);
                validate_button.set_visible(true);
                break;
            case "together":
                endpoint_entry.set_text("https://api.together.xyz/v1");
                add_together_models();
                api_key_entry.set_visible(true);
                validate_button.set_visible(true);
                break;
            case "ollama":
                endpoint_entry.set_text("http://localhost:11434");
                model_combo.append("llama3.2", "llama3.2");
                model_combo.append("llama3.1:70b", "llama3.1:70b");
                model_combo.append("mistral", "mistral");
                model_combo.set_active_id("llama3.2");
                api_key_entry.set_visible(false);
                validate_button.set_visible(true);
                break;
            default:
                endpoint_entry.set_text("https://api.openai.com/v1");
                add_common_models();
                break;
        }
        
        // Reset status indicators
        api_key_status_icon.set_visible(false);
        api_key_status_label.set_visible(false);
    }
    
    private void add_common_models()
    {
        model_combo.append("gpt-4o-mini", "GPT-4o Mini (economico)");
        model_combo.append("gpt-4o", "GPT-4o (potente)");
        model_combo.append("gpt-3.5-turbo", "GPT-3.5 Turbo (veloce)");
        model_combo.set_active_id("gpt-4o-mini");
    }
    
    private void add_openrouter_models()
    {
        model_combo.append("meta-llama/llama-3.2-3b-instruct", "Llama 3.2 3B (gratuito)");
        model_combo.append("meta-llama/llama-3.2-11b-vision-instruct", "Llama 3.2 11B (gratuito)");
        model_combo.append("mistralai/mistral-7b-instruct", "Mistral 7B (gratuito)");
        model_combo.append("google/gemma-2-9b-it", "Gemma 2 9B (gratuito)");
        model_combo.set_active_id("meta-llama/llama-3.2-3b-instruct");
    }
    
    private void add_together_models()
    {
        model_combo.append("meta-llama/Llama-3.2-3B-Instruct-Turbo", "Llama 3.2 3B");
        model_combo.append("meta-llama/Llama-3.3-70B-Instruct-Turbo", "Llama 3.3 70B");
        model_combo.append("mistralai/Mixtral-8x7B-Instruct-v0.1", "Mixtral 8x7B");
        model_combo.set_active_id("meta-llama/Llama-3.2-3B-Instruct-Turbo");
    }
    
    private void on_validate_clicked()
    {
        var provider_type = provider_combo.get_active_id();
        var api_key = api_key_entry.get_text();
        var endpoint = endpoint_entry.get_text();
        var model = model_combo.get_active_id();
        
        // Save current settings before validation
        settings.set_string("ai-provider-type", provider_type ?? "groq");
        settings.set_string("ai-api-key", api_key);
        settings.set_string("ai-api-endpoint", endpoint);
        if (model != "")
        {
            settings.set_string("ai-model", model);
        }

        // For providers that need API key, check if it's set
        if (provider_type != "ollama" && api_key.length == 0)
        {
            show_validation_status(_("⚠️ Inserisci prima una API Key"), "warning");
            return;
        }
        
        // For Groq, fetch available models and validate
        if (provider_type == "groq")
        {
            fetch_groq_models_and_validate(api_key);
            return;
        }

        // Start validation for other providers
        validation_spinner.start();
        validate_button.set_sensitive(false);
        api_key_status_label.set_visible(false);

        validator = new ApiKeyValidator(provider_type ?? "openai", api_key, endpoint);
        validator.validation_complete.connect((result) => {
            validation_spinner.stop();
            validate_button.set_sensitive(true);
            
            if (result.valid)
            {
                show_validation_status("✓ " + result.message, "success");
                api_key_status_icon.set_from_icon_name("object-select-symbolic");
                api_key_status_icon.add_css_class("success-icon");
                api_key_status_icon.set_visible(true);
                
                if (result.model_info != null)
                {
                    api_key_status_label.set_label(" | " + result.model_info);
                    api_key_status_label.set_visible(true);
                }
            }
            else
            {
                show_validation_status("✗ " + result.message, "error");
                api_key_status_icon.set_from_icon_name("dialog-error-symbolic");
                api_key_status_icon.add_css_class("error-icon");
                api_key_status_icon.set_visible(true);
                
                if (result.error_details != null)
                {
                    api_key_status_label.set_label(" | " + result.error_details);
                    api_key_status_label.set_visible(true);
                }
            }
        });
        
        validator.validate();
    }
    
    /**
     * Fetch available models from Groq API and populate dropdown
     */
    private void fetch_groq_models_and_validate(string api_key)
    {
        validate_button.set_sensitive(false);
        
        var session = new Soup.Session();
        var message = new Soup.Message("GET", "https://api.groq.com/openai/v1/models");
        message.request_headers.append("Authorization", "Bearer %s".printf(api_key));
        
        session.send_and_read_async.begin(message, Priority.DEFAULT, null, (obj, res) => {
            try
            {
                var bytes = session.send_and_read_async.end(res);
                
                if (message.status_code == 200)
                {
                    var response = (string) bytes.get_data();
                    var parser = new Json.Parser();
                    parser.load_from_data(response);
                    
                    var root_obj = parser.get_root().get_object();
                    var models = root_obj.get_array_member("data");
                    
                    // Clear and populate combo with actual models
                    model_combo.remove_all();
                    
                    int text_models = 0;
                    var saved_model = settings.get_string("ai-model");
                    bool found_saved = false;
                    
                    for (uint i = 0; i < models.get_length(); i++)
                    {
                        var model_obj = models.get_object_element(i);
                        var model_id = model_obj.get_string_member("id");
                        
                        // Filter for text/chat models only (exclude audio, safety, etc.)
                        if (model_id.contains("llama") || 
                            model_id.contains("gpt") || 
                            model_id.contains("gemma") || 
                            model_id.contains("qwen") ||
                            model_id.contains("compound"))
                        {
                            // Get context window if available
                            var context = model_obj.has_member("context_window") 
                                ? model_obj.get_int_member("context_window") : 0;
                            
                            string display_name = model_id;
                            if (model_id == "llama-3.3-70b-versatile")
                                display_name = "🏆 " + model_id + " (best for reasoning)";
                            else if (model_id.contains("120b"))
                                display_name = "🧠 " + model_id + " (max reasoning)";
                            else if (model_id.contains("8b") || model_id.contains("20b"))
                                display_name = "⚡ " + model_id + " (fast)";
                            else if (context >= 100000)
                                display_name = "📜 " + model_id + " (" + ((int)(context/1000)).to_string() + "k ctx)";

                            model_combo.append(model_id, display_name);
                            text_models++;

                            if (model_id == saved_model)
                                found_saved = true;
                        }
                    }

                    // Select saved model or first one
                    if (found_saved)
                    {
                        model_combo.set_active_id(saved_model);
                    }
                    else if (text_models > 0)
                    {
                        model_combo.set_active(0);
                    }

                    show_validation_status("✓ API Key valida! %d modelli trovati".printf(text_models), "success");
                    api_key_status_icon.set_from_icon_name("object-select-symbolic");
                    api_key_status_icon.add_css_class("success-icon");
                    api_key_status_icon.set_visible(true);
                    api_key_status_label.set_label(" | " + text_models.to_string() + " modelli disponibili");
                    api_key_status_label.set_visible(true);
                }
                else if (message.status_code == 401)
                {
                    show_validation_status("✗ API Key non valida", "error");
                    api_key_status_icon.set_from_icon_name("dialog-error-symbolic");
                    api_key_status_icon.add_css_class("error-icon");
                    api_key_status_icon.set_visible(true);
                }
                else
                {
                    show_validation_status("✗ Errore: HTTP %d".printf((int) message.status_code), "error");
                }
            }
            catch (Error e)
            {
                show_validation_status("✗ Errore: %s".printf(e.message), "error");
            }
            finally
            {
                validate_button.set_sensitive(true);
            }
        });
    }
    
    private void show_validation_status(string message, string type)
    {
        api_key_status_label.set_label(message);
        api_key_status_label.set_visible(true);
        
        // Remove old classes
        api_key_status_label.remove_css_class("success-label");
        api_key_status_label.remove_css_class("error-label");
        api_key_status_label.remove_css_class("warning-label");
        
        // Add appropriate class
        if (type == "success")
            api_key_status_label.add_css_class("success-label");
        else if (type == "error")
            api_key_status_label.add_css_class("error-label");
        else if (type == "warning")
            api_key_status_label.add_css_class("warning-label");
    }
    
    private void show_save_status(string message)
    {
        if (save_status_timeout != 0)
        {
            Source.remove(save_status_timeout);
        }
        
        save_status_label.set_label("✓ " + message);
        save_status_label.set_visible(true);
        save_status_label.add_css_class("success-label");
        
        save_status_timeout = Timeout.add(3000, () => {
            save_status_label.set_visible(false);
            save_status_timeout = 0;
            return Source.REMOVE;
        });
    }
}
