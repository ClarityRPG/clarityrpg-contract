import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

describe("ClarityRPG contract tests", () => {
    it("ensures simnet is well initialised", () => {
        expect(simnet.blockHeight).toBeDefined();
    });

    it("can create a hero and retrieve it", () => {
        const createResult = simnet.callPublicFn(
            "clarityrpg",
            "create-hero",
            [
                { type: "string-utf8", value: "Zephyros" },
                { type: "string-ascii", value: "mage" }
            ],
            wallet1
        );
        expect(createResult.result).toBeOk(simnet.uint(1));

        // Get hero sheet
        const getHeroResult = simnet.callReadOnlyFn("clarityrpg", "get-hero", [simnet.uint(1)], wallet1);
        const heroData: any = getHeroResult.result;
        expect(heroData.value.data.name).toEqual(simnet.utf8("Zephyros"));
        expect(heroData.value.data.class).toEqual(simnet.ascii("mage"));
        expect(heroData.value.data.level).toEqual(simnet.uint(1));
        
        // Ensure another call by same wallet fails with hero limit reached (u513)
        const createResult2 = simnet.callPublicFn(
            "clarityrpg",
            "create-hero",
            [
                { type: "string-utf8", value: "SecondHero" },
                { type: "string-ascii", value: "warrior" }
            ],
            wallet1
        );
        expect(createResult2.result).toBeErr(simnet.uint(513));
    });

    it("can allocate stat points", () => {
        // Create hero first
        simnet.callPublicFn("clarityrpg", "create-hero", [{ type: "string-utf8", value: "Hero" }, { type: "string-ascii", value: "warrior" }], wallet1);
        
        const allocateResult = simnet.callPublicFn(
            "clarityrpg",
            "allocate-stat-points",
            [
                simnet.uint(1), // hero-id
                simnet.uint(1), // str
                simnet.uint(0), // dex
                simnet.uint(0), // int
                simnet.uint(2), // vit
                simnet.uint(0)  // lck
            ],
            wallet1
        );
        expect(allocateResult.result).toBeOk(simnet.bool(true));

        // Unallocated points should be 0 now
        const unallocatedResult = simnet.callReadOnlyFn("clarityrpg", "get-unallocated-points", [simnet.uint(1)], wallet1);
        expect(unallocatedResult.result).toBeSome(simnet.uint(0));
    });

    it("counter utility works for testing", () => {
        let counter = simnet.callReadOnlyFn("clarityrpg", "get-counter", [], wallet1);
        expect(counter.result).toBeInt(0);

        simnet.callPublicFn("clarityrpg", "increment", [], wallet1);
        simnet.callPublicFn("clarityrpg", "increment", [], wallet1);
        counter = simnet.callReadOnlyFn("clarityrpg", "get-counter", [], wallet1);
        expect(counter.result).toBeOk(simnet.int(2));

        simnet.callPublicFn("clarityrpg", "decrement", [], wallet1);
        counter = simnet.callReadOnlyFn("clarityrpg", "get-counter", [], wallet1);
        expect(counter.result).toBeOk(simnet.int(1));
    });
});
