// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BasedBadge is ERC1155, AccessControl, Pausable, ERC1155Supply {
    using Strings for uint256;

    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public constant CERTIFICATE_BASE = 1000;
    uint256 public constant EVENT_BADGE_BASE = 2000;
    uint256 public constant ACHIEVEMENT_BASE = 3000;
    uint256 public constant WORKSHOP_BASE = 4000;

    struct TokenInfo {
        string name;
        string category;
        uint256 maxSupply;
        bool isTransferable;
        uint256 validUntil;
        address issuer;
    }

    mapping(uint256 => TokenInfo) public tokenInfo;
    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256[]) public holderTokens;
    mapping(uint256 => mapping(address => uint256)) public earnedAt;

    uint256 private _certificateCounter;
    uint256 private _eventCounter;
    uint256 private _achievementCounter;
    uint256 private _workshopCounter;

    event TokenTypeCreated(uint256 indexed tokenId, string name, string category);
    event BadgeIssued(uint256 indexed tokenId, address to);
    event BatchBadgesIssued(uint256 indexed tokenId, uint256 count);
    event AchievementGranted(uint256 indexed tokenId, address student, string achievement);

    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    // Helper function to check if token exists
    function _tokenExists(uint256 tokenId) private view returns (bool) {
        return tokenInfo[tokenId].issuer != address(0);
    }

    function createBadgeType(
        string memory name,
        string memory category,
        uint256 maxSupply,
        bool transferable,
        string memory tokenURI
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId;
        uint256 base;

        if (keccak256(bytes(category)) == keccak256(bytes("certificate"))) {
            base = CERTIFICATE_BASE;
            tokenId = base + _certificateCounter++;
        } else if (keccak256(bytes(category)) == keccak256(bytes("event"))) {
            base = EVENT_BADGE_BASE;
            tokenId = base + _eventCounter++;
        } else if (keccak256(bytes(category)) == keccak256(bytes("achievement"))) {
            base = ACHIEVEMENT_BASE;
            tokenId = base + _achievementCounter++;
        } else if (keccak256(bytes(category)) == keccak256(bytes("workshop"))) {
            base = WORKSHOP_BASE;
            tokenId = base + _workshopCounter++;
        } else {
            revert("Invalid category");
        }

        tokenInfo[tokenId] = TokenInfo({
            name: name,
            category: category,
            maxSupply: maxSupply,
            isTransferable: transferable,
            validUntil: 0,
            issuer: msg.sender
        });

        _tokenURIs[tokenId] = tokenURI;
        emit TokenTypeCreated(tokenId, name, category);
        return tokenId;
    }

    function issueBadge(address to, uint256 tokenId) public onlyRole(MINTER_ROLE) {
        require(_tokenExists(tokenId), "Token does not exist");
        require(
            tokenInfo[tokenId].maxSupply == 0 ||
            totalSupply(tokenId) < tokenInfo[tokenId].maxSupply,
            "Max supply reached"
        );

        _mint(to, tokenId, 1, "");
        earnedAt[tokenId][to] = block.timestamp;
        holderTokens[to].push(tokenId);
        emit BadgeIssued(tokenId, to);
    }

    function batchIssueBadges(
        address[] memory recipients,
        uint256 tokenId,
        uint256 amount
    ) public onlyRole(MINTER_ROLE) {
        require(_tokenExists(tokenId), "Token does not exist");
        require(
            tokenInfo[tokenId].maxSupply == 0 ||
            totalSupply(tokenId) + recipients.length * amount <= tokenInfo[tokenId].maxSupply,
            "Max supply would be exceeded"
        );

        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], tokenId, amount, "");
            earnedAt[tokenId][recipients[i]] = block.timestamp;
            holderTokens[recipients[i]].push(tokenId);
        }

        emit BatchBadgesIssued(tokenId, recipients.length * amount);
    }

    function grantAchievement(
        address student,
        string memory achievementName,
        uint256 rarity
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = ACHIEVEMENT_BASE + _achievementCounter++;

        tokenInfo[tokenId] = TokenInfo({
            name: achievementName,
            category: "achievement",
            maxSupply: rarity,
            isTransferable: false,
            validUntil: 0,
            issuer: msg.sender
        });

        _mint(student, tokenId, 1, "");
        earnedAt[tokenId][student] = block.timestamp;
        holderTokens[student].push(tokenId);

        emit AchievementGranted(tokenId, student, achievementName);
        return tokenId;
    }

    function createWorkshop(
        string memory seriesName,
        uint256 totalSessions
    ) public onlyRole(MINTER_ROLE) returns (uint256[] memory) {
        uint256[] memory sessionIds = new uint256[](totalSessions);

        for (uint256 i = 0; i < totalSessions; i++) {
            uint256 tokenId = WORKSHOP_BASE + _workshopCounter++;
            tokenInfo[tokenId] = TokenInfo({
                name: string.concat(seriesName, " Session ", i.toString()),
                category: "workshop",
                maxSupply: 0, // unlimited
                isTransferable: true,
                validUntil: 0,
                issuer: msg.sender
            });

            sessionIds[i] = tokenId;
        }

        return sessionIds;
    }

    function setURI(uint256 tokenId, string memory newURI) public onlyRole(URI_SETTER_ROLE) {
        require(_tokenExists(tokenId), "Token does not exist");
        _tokenURIs[tokenId] = newURI;
    }

    function getTokensByHolder(address holder) public view returns (uint256[] memory) {
        return holderTokens[holder];
    }

    function verifyBadge(address holder, uint256 tokenId)
        public view returns (bool valid, uint256 earnedTimestamp)
    {
        require(_tokenExists(tokenId), "Token does not exist");

        valid = balanceOf(holder, tokenId) > 0;
        if (valid) {
            earnedTimestamp = earnedAt[tokenId][holder];
            if (tokenInfo[tokenId].validUntil > 0) {
                valid = block.timestamp <= tokenInfo[tokenId].validUntil;
            }
        }
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        for (uint256 i = 0; i < ids.length; i++) {
            require(_tokenExists(ids[i]), "Token does not exist");
            if (from != address(0) && to != address(0)) {
                require(
                    tokenInfo[ids[i]].isTransferable,
                    "This token is non-transferable"
                );
            }
        }
        super._update(from, to, ids, values);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        require(_tokenExists(tokenId), "Token does not exist");
        return _tokenURIs[tokenId];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}