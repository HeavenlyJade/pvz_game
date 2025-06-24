local actor = game.Players.LocalPlayer
print("actor.TouchMovementMode", actor, actor.TouchMovementMode)
if game.RunService:IsPC() then
    actor.TouchMovementMode = Enum.DevTouchMovementMode.Scriptable
else
    actor.TouchMovementMode = Enum.DevTouchMovementMode.Thumbstick
end
