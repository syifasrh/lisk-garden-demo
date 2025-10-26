// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract LiskGarden {
    // 1. Data Type
    enum GrowthStage { SEED, SPROUT, GROWING, BLOOMING }

    struct Plant {
        uint256 id;
        address owner;
        GrowthStage stage;
        uint256 plantedDate;
        uint256 lastWatered;
        uint8 waterLevel;
        bool exists;
        bool isDead;
    }

    // 2. State
    mapping(uint256 => Plant) public plants;
    mapping(address => uint256[]) public userPlants;
    uint256 public plantCounter;
    address public owner;

    // 3. Constants
    uint256 public constant PLANT_PRICE = 0.001 ether;
    uint256 public constant HARVEST_REWARD = 0.003 ether;
    uint256 public constant STAGE_DURATION = 1 minutes;
    uint256 public constant WATER_DEPLESSION_TIME = 30 seconds;
    uint8 public constant WATER_DEPLETION_RATE = 2;

    // 4. Events
    event PlantSeeded(address indexed owner, uint256 indexed plantId);
    event PlantWatered(uint256 indexed plantId, uint8 newWaterLevel);
    event PlantHarvested(uint256 indexed plantId, address indexed owner, uint256 reward);
    event StageAdvanced(uint256 indexed plantId, GrowthStage newStage);
    event PlantDied(uint256 indexed plantId);

    // 5. Constructor
    constructor() {
        owner = msg.sender;
    }

    // 6. Main Functions (8 functions)
    // Terima ETH
    function deposit() public payable {}
    
    // Cek saldo
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function plantSeed() external payable returns (uint256) {
        require(msg.value >= PLANT_PRICE, "Need 0.001 ETH");
        plantCounter++;

        plants[plantCounter] = Plant({
            id: plantCounter,
            owner: msg.sender,
            stage: GrowthStage.SEED,
            plantedDate: block.timestamp,
            lastWatered: block.timestamp,
            waterLevel: 100,
            exists: true,
            isDead: false
        });

        userPlants[msg.sender].push(plantCounter);
        emit PlantSeeded(msg.sender, plantCounter);
        return plantCounter;
    }

    function calculateWaterLevel(uint256 plantId) public view returns (uint8) {
        Plant storage plant = plants[plantId];
        if (!plant.exists || plant.isDead) {
            return 0;
        }

        uint256 timeSinceWatered = block.timestamp - plant.lastWatered;
        uint256 depletionIntervals = timeSinceWatered / WATER_DEPLESSION_TIME;
        uint256 waterLost = depletionIntervals * WATER_DEPLETION_RATE;

        if (waterLost >= plant.waterLevel) {
            return 0;
        }
        return plant.waterLevel - uint8(waterLost);
    }

    function updateWaterLevel(uint256 plantId) internal {
        Plant storage plant = plants[plantId];
        uint8 currentWater = calculateWaterLevel(plantId);
        plant.waterLevel = currentWater;

        if (currentWater == 0 && !plant.isDead) {
            plant.isDead = true;
            emit PlantDied(plantId);
        }
    }

    function waterPlant(uint256 plantId) external {
        Plant storage plant = plants[plantId];
        require(plant.exists, "Plant does not exist");
        require(msg.sender == plant.owner, "Only the plant owner can water it");
        require(!plant.isDead, "Plant is dead and cannot be watered");

        plant.waterLevel = 100;
        plant.lastWatered = block.timestamp;
        emit PlantWatered(plantId, 100);
        updatePlantStage(plantId);
    }

    function updatePlantStage(uint256 plantId) public {
        Plant storage plant = plants[plantId];
        require(plant.exists, "Plant does not exist");

        updateWaterLevel(plantId);
        if (plant.isDead) return;

        uint256 timeSincePlanted = block.timestamp - plant.plantedDate;
        GrowthStage oldStage = plant.stage;

        if (timeSincePlanted >= 3 * STAGE_DURATION) {
            plant.stage = GrowthStage.BLOOMING;
        } else if (timeSincePlanted >= 2 * STAGE_DURATION) {
            plant.stage = GrowthStage.GROWING;
        } else if (timeSincePlanted >= STAGE_DURATION) {
            plant.stage = GrowthStage.SPROUT;
        }

        if (plant.stage != oldStage) {
            emit StageAdvanced(plantId, plant.stage);
        }
    }

    function harvestPlant(uint256 plantId) external {
        Plant storage plant = plants[plantId];
        require(plant.exists, "Plant does not exist");
        require(msg.sender == plant.owner, "Only the plant owner can harvest");
        require(!plant.isDead, "Plant is dead and cannot be harvested");

        updatePlantStage(plantId);
        require(plant.stage == GrowthStage.BLOOMING, "Plant must be blooming to harvest");

        plant.exists = false;
        emit PlantHarvested(plantId, plant.owner, HARVEST_REWARD);

        (bool success, ) = msg.sender.call{value: HARVEST_REWARD}("");
        require(success, "Failed to send harvest reward");
    }

    // 7. Helper Functions (3 functions)
    function getPlant(uint256 plantId) external view returns (Plant memory) {
        Plant memory plant = plants[plantId];
        plant.waterLevel = calculateWaterLevel(plantId);
        return plant;
    }

    function getUserPlants(address user) external view returns (uint256[] memory) {
        return userPlants[user];
    }

    function withdraw() external {
        require(msg.sender == owner, "Not owner");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
    
    // 8. Receive ETH
    receive() external payable {}
}