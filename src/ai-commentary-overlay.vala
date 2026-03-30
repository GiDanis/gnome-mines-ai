/*
 * Copyright (C) 2026 GNOME Mines AI Contributors
 */

using Gtk;
using Adw;

/**
 * Sidebar panel that displays AI commentary and reasoning history
 * Has expandable levels: Compact → Messages → Full Reasoning
 */
public class AiCommentaryOverlay : Gtk.Box
{
    private Gtk.Box messages_box;
    private Gtk.Label title_label;
    private Gtk.Label model_label;
    private Gtk.ScrolledWindow scroll;
    private Gtk.Button expand_button;
    private Gtk.Box reasoning_box;
    private Gtk.Label reasoning_label;
    
    private bool expanded = false;
    private const int MAX_MESSAGES = 50;
    private int message_count = 0;

    public AiCommentaryOverlay()
    {
        Object(
            orientation: Orientation.VERTICAL,
            spacing: 0
        );

        set_size_request(280, -1);
        setup_ui();
    }

    private void setup_ui()
    {
        add_css_class("ai-log-panel");

        // Title bar with expand button
        var title_box = new Gtk.Box(Orientation.HORIZONTAL, 6);
        title_box.add_css_class("ai-log-header");
        title_box.set_margin_start(12);
        title_box.set_margin_end(12);
        title_box.set_margin_top(8);
        title_box.set_margin_bottom(8);

        var ai_icon = new Gtk.Image.from_icon_name("dialog-information-symbolic");
        ai_icon.set_pixel_size(18);
        title_box.append(ai_icon);

        title_label = new Gtk.Label("🤖 AI Reasoning");
        title_label.add_css_class("ai-log-title");
        title_label.set_xalign(0);
        title_label.set_hexpand(true);
        title_box.append(title_label);
        
        // Model label (shows current model)
        model_label = new Gtk.Label("");
        model_label.add_css_class("ai-log-model");
        model_label.set_xalign(1);
        model_label.set_hexpand(false);
        title_box.append(model_label);
        
        // Expand/Collapse button
        expand_button = new Gtk.Button.from_icon_name("pan-down-symbolic");
        expand_button.add_css_class("flat");
        expand_button.set_tooltip_text("Espandi/Comprimi ragionamento");
        expand_button.clicked.connect(on_expand_clicked);
        title_box.append(expand_button);

        append(title_box);
        
        // Separator
        append(new Gtk.Separator(Orientation.HORIZONTAL));

        // Messages container (scrollable wrapper)
        scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        scroll.set_vexpand(true);
        
        messages_box = new Gtk.Box(Orientation.VERTICAL, 4);
        messages_box.set_margin_start(12);
        messages_box.set_margin_end(12);
        messages_box.set_margin_top(8);
        messages_box.set_margin_bottom(8);
        
        scroll.set_child(messages_box);
        append(scroll);
        
        // Reasoning box (hidden by default, shows full <think>)
        reasoning_box = new Gtk.Box(Orientation.VERTICAL, 4);
        reasoning_box.set_margin_start(12);
        reasoning_box.set_margin_end(12);
        reasoning_box.set_margin_top(8);
        reasoning_box.set_margin_bottom(8);
        reasoning_box.set_visible(false);
        
        var reasoning_scroll = new Gtk.ScrolledWindow();
        reasoning_scroll.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        reasoning_scroll.set_vexpand(false);
        reasoning_scroll.set_vexpand_set(true);
        
        reasoning_label = new Gtk.Label("");
        reasoning_label.set_wrap(true);
        reasoning_label.set_xalign(0);
        reasoning_label.add_css_class("ai-log-reasoning");
        reasoning_scroll.set_child(reasoning_label);
        
        reasoning_box.append(reasoning_scroll);
        append(reasoning_box);
        
        // Initial empty state
        add_empty_state();
    }
    
    private void on_expand_clicked()
    {
        expanded = !expanded;
        reasoning_box.set_visible(expanded);
        
        if (expanded)
        {
            expand_button.set_icon_name("pan-up-symbolic");
            expand_button.set_tooltip_text("Comprimi ragionamento");
        }
        else
        {
            expand_button.set_icon_name("pan-down-symbolic");
            expand_button.set_tooltip_text("Espandi ragionamento");
        }
    }
    
    private void add_empty_state()
    {
        var empty_label = new Gtk.Label("AI will show reasoning here...");
        empty_label.add_css_class("ai-log-empty");
        empty_label.set_wrap(true);
        empty_label.set_xalign(0);
        messages_box.append(empty_label);
    }
    
    /**
     * Add a new AI message to the log
     */
    public void add_message(string text, string type = "info")
    {
        // Remove empty state on first message
        if (message_count == 0 && messages_box.get_first_child() != null)
        {
            var first = messages_box.get_first_child();
            if (first is Gtk.Label)
            {
                messages_box.remove(first);
            }
        }
        
        // Create message row
        var msg_box = new Gtk.Box(Orientation.HORIZONTAL, 6);
        msg_box.add_css_class("ai-log-message");
        
        // Icon based on type
        string icon_name = "dialog-information-symbolic";
        if (type == "flag") icon_name = "flag-symbolic";
        else if (type == "click") icon_name = "go-next-symbolic";
        else if (type == "error") icon_name = "dialog-error-symbolic";
        else if (type == "think") icon_name = "preferences-system-time-symbolic";
        
        var icon = new Gtk.Image.from_icon_name(icon_name);
        icon.set_pixel_size(14);
        icon.add_css_class("ai-log-icon-" + type);
        msg_box.append(icon);
        
        // Message text
        var label = new Gtk.Label(text);
        label.set_wrap(true);
        label.set_xalign(0);
        label.add_css_class("ai-log-text");
        label.add_css_class("ai-log-text-" + type);
        msg_box.append(label);
        
        messages_box.append(msg_box);
        message_count++;
        
        // Limit messages
        if (message_count > MAX_MESSAGES)
        {
            var first = messages_box.get_first_child();
            if (first != null)
                messages_box.remove(first);
            message_count--;
        }

        // Auto-scroll to bottom
        if (this.scroll != null)
        {
            var adj = this.scroll.get_vadjustment();
            Timeout.add(50, () => {
                adj.set_value(adj.get_upper() - adj.get_page_size());
                return Source.REMOVE;
            });
        }
    }
    
    /**
     * Clear all messages
     */
    public void clear()
    {
        var child = messages_box.get_first_child();
        while (child != null)
        {
            var next = child.get_next_sibling();
            messages_box.remove(child);
            child = next;
        }
        message_count = 0;
        add_empty_state();
    }
    
    /**
     * Set the current AI model name
     */
    public void set_model(string model_name)
    {
        if (model_label == null)
            return;
            
        // Extract short model name (e.g., "llama-3.3-70b" from "llama-3.3-70b-versatile")
        string short_name = model_name;
        if (model_name.contains("/"))
        {
            string[] parts = model_name.split("/");
            short_name = parts[parts.length - 1];
        }

        // Truncate if too long
        if (short_name.length > 20)
            short_name = short_name.substring(0, 17) + "...";

        model_label.set_label("🤖 " + short_name);
        model_label.set_tooltip_text(model_name);
    }
    
    /**
     * Set the full reasoning text (shows in expanded view)
     */
    public void set_reasoning(string reasoning)
    {
        if (reasoning_label != null && reasoning != null)
        {
            reasoning_label.set_label(reasoning);
        }
    }
}
