package com.ecomasters.game;

import java.util.ArrayList;
import java.util.List;
import org.godotengine.godot.GodotActivity;

/** Hosts the native Godot runtime and its exported Eco Masters pack. */
public final class MainActivity extends GodotActivity {
    @Override
    public List<String> getCommandLine() {
        List<String> commandLine = new ArrayList<>(super.getCommandLine());
        commandLine.add("--main-pack");
        commandLine.add("res://main.pck");
        return commandLine;
    }
}
