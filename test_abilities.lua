local AbilityScanner = require(
    "AbilityScanner"
)


print("===== EQUIPPED ABILITIES =====")


local abilities =
    AbilityScanner:GetEquipped()


for _,ability in ipairs(abilities) do

    print(
        "Slot:",
        ability.Slot
    )

    print(
        "Name:",
        ability.Name
    )

    print(
        "Cooldown:",
        ability.Cooldown
    )

    print("----------------")

end


print("===== COMPLETE =====")