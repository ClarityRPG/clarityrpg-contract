import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

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
                Cl.stringUtf8("Zephyros"),
                Cl.stringAscii("mage")
            ],
            wallet1
        );
        expect(createResult.result).toBeOk(Cl.uint(1));

        // Get hero sheet
        const getHeroResult = simnet.callReadOnlyFn("clarityrpg", "get-hero", [Cl.uint(1)], wallet1);
        const heroData: any = getHeroResult.result;
        expect(heroData.value.data.name).toEqual(Cl.stringUtf8("Zephyros"));
        expect(heroData.value.data.class).toEqual(Cl.stringAscii("mage"));
        expect(heroData.value.data.level).toEqual(Cl.uint(1));

        // Ensure another call by same wallet fails with hero limit reached (u513)
        const createResult2 = simnet.callPublicFn(
            "clarityrpg",
            "create-hero",
            [
                Cl.stringUtf8("SecondHero"),
                Cl.stringAscii("warrior")
            ],
            wallet1
        );
        expect(createResult2.result).toBeErr(Cl.uint(513));
    });

    it("can allocate stat points", () => {
        // Create hero first
        simnet.callPublicFn("clarityrpg", "create-hero", [Cl.stringUtf8("Hero"), Cl.stringAscii("warrior")], wallet1);

        const allocateResult = simnet.callPublicFn(
            "clarityrpg",
            "allocate-stat-points",
            [
                Cl.uint(1), // hero-id
                Cl.uint(1), // str
                Cl.uint(0), // dex
                Cl.uint(0), // int
                Cl.uint(2), // vit
                Cl.uint(0)  // lck
            ],
            wallet1
        );
        expect(allocateResult.result).toBeOk(Cl.bool(true));

        // Unallocated points should be 0 now
        const unallocatedResult = simnet.callReadOnlyFn("clarityrpg", "get-unallocated-points", [Cl.uint(1)], wallet1);
        expect(unallocatedResult.result).toBeSome(Cl.uint(0));
    });

    it("counter utility works for testing", () => {
        let counter = simnet.callReadOnlyFn("clarityrpg", "get-counter", [], wallet1);
        expect(counter.result).toBeInt(0);

        simnet.callPublicFn("clarityrpg", "increment", [], wallet1);
        simnet.callPublicFn("clarityrpg", "increment", [], wallet1);
        counter = simnet.callReadOnlyFn("clarityrpg", "get-counter", [], wallet1);
        expect(counter.result).toBeOk(Cl.int(2));

        simnet.callPublicFn("clarityrpg", "decrement", [], wallet1);
        counter = simnet.callReadOnlyFn("clarityrpg", "get-counter", [], wallet1);
        expect(counter.result).toBeOk(Cl.int(1));
    });
});
