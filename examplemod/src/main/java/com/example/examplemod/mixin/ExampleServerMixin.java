package com.example.examplemod.mixin;

import java.util.function.BooleanSupplier;

import net.minecraft.server.MinecraftServer;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Demonstrates Mixin support: injects into the vanilla server tick loop and
 * logs every 200 ticks (~10s). Targets the real Mojang-mapped class/method
 * names directly since this snapshot is unobfuscated - no refmap needed.
 */
@Mixin(MinecraftServer.class)
public class ExampleServerMixin {
    @Inject(method = "tickServer", at = @At("HEAD"))
    private void examplemod$onTick(BooleanSupplier hasTimeLeft, CallbackInfo ci) {
        MinecraftServer self = (MinecraftServer) (Object) this;
        if (self.getTickCount() % 200 == 0) {
            System.out.println("[examplemod] mixin alive, tick " + self.getTickCount());
        }
    }
}
