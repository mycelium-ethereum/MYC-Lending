forge build --use 0.8.13

lentMycV1="0x9B225FF56C48671d4D04786De068Ed8b88b672d6"
# 12. Upgrade `LentMyc` to `LentMycWithMigration`.
        # lProxy.upgradeTo(address(dummyUpgrade));
cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $lentMycV1 \
    "upgradeTo(address)" \
    $LMYC_WITH_MIGRATION

# 13. Verify that all variables are correctly set.
# 14. Verify on etherscan:
    # - RewardDistributor.
    # - RewardTracker.
    # - LentMycWithMigration (and new proxy).
    # - RewardTracker proxy.
    # - RewardDistributor proxy.
LBLUE='\033[1;36m'
echo ""
echo -e "${LBLUE}--- NEXT STEPS ---"
echo "Ensure lentMyc variables are all set correctly"
echo "Then Verify all contracts on Etherscan."
echo "12. Upgrade `LentMyc` to `LentMycWithMigration`.
        # lProxy.upgradeTo(address(dummyUpgrade));"
echo "15. Call `LentMycWithMigration.setDepositWithdrawPaused(true)`."
echo "16. Call `LentMycWithMigration.setInPausedTransferMode(true)`."
echo "17. Call `LentMycWithMigration.setV2RewardTrackerAndMigrator(address(rewardTrackerProxy), address(permissionedMigrator))`."
echo "18. Call `RewardTracker.setHandler(address(lentMycWithMigration), true);`."
echo "19. Migrate accounts."