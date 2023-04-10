// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";

contract TwTap is ERC20Permit, BoringOwnable {
    using SafeERC20 for IERC20;

    uint256 public constant DIST_PRECISION = 1e18;

    IERC20[] public rewardTokens;

    mapping(address => mapping(IERC20 => uint256)) public claimed;
    mapping(IERC20 => uint256) public distributedPerToken;

    constructor() ERC20Permit("twTAP") ERC20("twTAP", "twTAP") {}

    function claim(address to) public {
        _claim(msg.sender, to);
    }

    function distribute(uint256 rewardTokenId, uint256 amount) external {
        IERC20 rewardToken = rewardTokens[rewardTokenId];
        distributedPerToken[rewardToken] +=
            (amount * DIST_PRECISION) /
            totalSupply();
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function addRewardToken(IERC20 token) external onlyOwner returns (uint256) {
        uint256 i = rewardTokens.length;
        rewardTokens.push(token);
        return i;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from != address(0)) {
            _claim(from, from);
        }

        // The new holder is deemed to have already claimed all rewards for the
        // the transfer. Round up to favor the pool:
        uint256 len = rewardTokens.length;
        for (uint256 i = 0; i < len; ) {
            IERC20 rewardToken = rewardTokens[i];
            claimed[to][rewardToken] +=
                (distributedPerToken[rewardToken] *
                    amount +
                    DIST_PRECISION -
                    1) /
                DIST_PRECISION;
            unchecked {
                ++i;
            }
        }
    }

    function _claim(address account, address to) private {
        uint256 len = rewardTokens.length;
        for (uint256 i = 0; i < len; ) {
            IERC20 token = rewardTokens[i];
            uint256 dist = distributedPerToken[token];
            uint256 previous = claimed[account][token];
            uint256 total = (balanceOf(account) * dist) / DIST_PRECISION;
            unchecked {
                if (total > previous) {
                    token.safeTransfer(to, total - previous);
                    claimed[account][token] = total;
                }
                ++i;
            }
        }
    }
}
