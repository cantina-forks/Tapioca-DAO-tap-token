import 'prb-math/contracts/PRBMathSD59x18.sol';
import 'hardhat/console.sol';

contract TAPEmissionModel {
    using PRBMathSD59x18 for int256;

    int256 public constant A_PARAM = 24 * 10e17; // 24
    int256 public constant B_PARAM = 2500;
    int256 public constant C_PARAM = 37 * 10e16; // 3.7
    int256 public constant WEEK = 604800;
    int256 public constant emissionsStartTime = 0; // TBD
    mapping(int256 => bool) public weekMinted;

    /// @notice returns the available emissions for a specific week
    /// @dev formula: b(xe^(c-f(x))) where f(x)=x/a
    /// @dev constants: a = 24, b = 2500, c = 3.7
    /// @param x week number
    function computeEmissionPerWeek(int256 x) internal pure returns (int256 result) {
        int256 fx = PRBMathSD59x18.fromInt(x).div(A_PARAM);
        int256 pow = C_PARAM - fx;
        result = ((B_PARAM * x) * (PRBMathSD59x18.e().pow(pow))) / 1e18;
    }

    // TODO delete this function
    function test__emission(int256 x) public pure returns (int256 result) {
        result = computeEmissionPerWeek(x);
    }

    /// @notice returns the available emissions for a specific week
    /// @dev formula: b(xe^(c-f(x))) where f(x)=x/a
    /// @dev constants: a = 24, b = 2500, c = 3.7
    function availableEmissions(uint256 timestamp) public returns (uint256 emission) {
        if (timestamp != 0) {
            require(uint256(emissionsStartTime) < timestamp && timestamp <= block.timestamp, 'timestamp not valid');
        } else {
            timestamp = block.timestamp;
        }

        int256 x = (int256(timestamp) - emissionsStartTime) / WEEK;
        if (weekMinted[x]) return 0;
        weekMinted[x] = true;

        emission = uint256(computeEmissionPerWeek(x));
    }
}
