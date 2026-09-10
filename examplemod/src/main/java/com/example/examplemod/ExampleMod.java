package com.example.examplemod;

import net.fabricmc.api.ModInitializer;

public class ExampleMod implements ModInitializer {
    @Override
    public void onInitialize() {
        System.out.println("Hello from ExampleMod, built with Buck 2!");
    }
}
