LBLUE='\033[1;36m'
echo ""
echo -e "${LBLUE}--- NEXT STEPS ---"
echo "Ensure lentMyc variables are all set correctly"
echo "Then Verify all contracts on Etherscan."
echo "12. Upgrade `LentMyc` to `LentMycWithMigration`.
        # lMyc.upgradeTo(address(lentMycWithMigration));"
echo "15. Call `LentMycWithMigration.setDepositWithdrawPaused(true)`."
echo "16. Call `LentMycWithMigration.setInPausedTransferMode(true)`."
echo "17. Call `LentMycWithMigration.setV2RewardTrackerAndMigrator(address(rewardTrackerProxy), address(permissionedMigrator))`."
echo "18. Call `RewardTracker.setHandler(address(lentMycWithMigration), true);`."
echo "19. Call `RewardTracker.setInPrivateTransferMode(true);`."
echo "20. Migrate accounts."