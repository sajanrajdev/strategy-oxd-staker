from helpers.StrategyCoreResolver import StrategyCoreResolver
from rich.console import Console
from brownie import interface
from _setup.config import WANT

console = Console()


class StrategyResolver(StrategyCoreResolver):
    def get_strategy_destinations(self):
        """
        Track balances for all strategy implementations
        (Strategy Must Implement)
        """
        strategy = self.manager.strategy
        sett = self.manager.sett
        return {
            "StakingRewards": strategy.stakingAddress(),
            "bveOXD": strategy.bveOXD(),
            "bOxSolid": strategy.bOxSolid(),
            "badgerTree": sett.badgerTree(),
        }

    def add_balances_snap(self, calls, entities):
        super().add_balances_snap(calls, entities)
        strategy = self.manager.strategy

        oxd = interface.IERC20(strategy.OXD())
        oxSolid = interface.IERC20(strategy.OXSOLID())
        solid = interface.IERC20(strategy.SOLID())
        bveOXD = interface.IERC20(strategy.BVEOXD())
        bveOXD_OXD = interface.IERC20(strategy.BVEOXD_OXD())
        bOxSolid = interface.IERC20(strategy.BOXSOLID())
        bBveOXD_OXD = interface.IERC20(strategy.BBVEOXD_OXD())

        calls = self.add_entity_balances_for_tokens(calls, "oxd", oxd, entities)
        calls = self.add_entity_balances_for_tokens(calls, "oxSolid", oxSolid, entities)
        calls = self.add_entity_balances_for_tokens(calls, "solid", solid, entities)
        calls = self.add_entity_balances_for_tokens(calls, "bveOXD", bveOXD, entities)
        calls = self.add_entity_balances_for_tokens(calls, "bveOXD_OXD", bveOXD_OXD, entities)
        calls = self.add_entity_balances_for_tokens(calls, "bOxSolid", bOxSolid, entities)
        calls = self.add_entity_balances_for_tokens(calls, "bBveOXD_OXD", bBveOXD_OXD, entities)

        return calls

    def confirm_harvest(self, before, after, tx):
        console.print("=== Compare Harvest ===")
        self.manager.printCompare(before, after)
        self.confirm_harvest_state(before, after, tx)

        super().confirm_harvest(before, after, tx)

        assert len(tx.events["Harvested"]) == 1
        event = tx.events["Harvested"][0]

        # There is no autocompounding so harvested amount is 0
        assert event["token"] == WANT
        assert event["amount"] == 0

        assert len(tx.events["TreeDistribution"]) == 2

        tokens = [
            ("bBveOXD_OXD", self.manager.strategy.BBVEOXD_OXD()), 
            ("bOxSolid", self.manager.strategy.BOXSOLID())
        ]

        for (name, token), event in zip(tokens, tx.events["TreeDistribution"]):
            assert after.balances(name, "badgerTree") > before.balances(
                name, "badgerTree"
            )

            if before.get("sett.performanceFeeGovernance") > 0:
                assert after.balances(name, "treasury") > before.balances(
                    name, "treasury"
                )

            if before.get("sett.performanceFeeStrategist") > 0:
                assert after.balances(name, "strategist") > before.balances(
                    name, "strategist"
                )

            assert event["token"] == token
            assert event["amount"] == after.balances(
                name, "badgerTree"
            ) - before.balances(name, "badgerTree")
