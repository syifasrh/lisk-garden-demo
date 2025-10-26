// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BasedCertificate is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    uint256 private _nextTokenId;

    struct CertificateData {
        string recipientName;
        string course;
        string issuer;
        uint256 issuedDate;
        bool valid;
    }

    mapping(uint256 => CertificateData) public certificates;
    mapping(address => uint256[]) public ownerCertificates;
    mapping(bytes32 => uint256) public certHashToTokenId;

    event CertificateIssued(
        uint256 indexed tokenId,
        address recipient,
        string course,
        string issuer
    );
    event CertificateRevoked(uint256 indexed tokenId);
    event CertificateUpdated(uint256 indexed tokenId, string newCourse);

    constructor() ERC721("Based Certificate", "BCERT") Ownable(msg.sender) {}

    function _generateCertHash(
        address to,
        string memory recipientName,
        string memory course,
        string memory issuer
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(to, recipientName, course, issuer));
    }

    function issueCertificate(
        address to,
        string memory recipientName,
        string memory course,
        string memory issuer,
        string memory uri
    ) public onlyOwner {
        bytes32 certHash = _generateCertHash(to, recipientName, course, issuer);
        require(certHashToTokenId[certHash] == 0, "BCERT: duplicate certificate");

        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        certificates[tokenId] = CertificateData({
            recipientName: recipientName,
            course: course,
            issuer: issuer,
            issuedDate: block.timestamp,
            valid: true
        });

        ownerCertificates[to].push(tokenId);
        certHashToTokenId[certHash] = tokenId;

        emit CertificateIssued(tokenId, to, course, issuer);
    }

    function revokeCertificate(uint256 tokenId) public onlyOwner {
        require(ownerOf(tokenId) != address(0), "BCERT: token does not exist");
        certificates[tokenId].valid = false;
        emit CertificateRevoked(tokenId);
    }

    function updateCertificate(uint256 tokenId, string memory newCourse) public onlyOwner {
        require(ownerOf(tokenId) != address(0), "BCERT: token does not exist");
        certificates[tokenId].course = newCourse;
        emit CertificateUpdated(tokenId, newCourse);
    }

    function getCertificatesByOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        return ownerCertificates[owner];
    }

    function burnCertificate(uint256 tokenId) public onlyOwner {
        address owner = ownerOf(tokenId);
        require(owner != address(0), "BCERT: token does not exist");

        bytes32 certHash = _generateCertHash(
            owner,
            certificates[tokenId].recipientName,
            certificates[tokenId].course,
            certificates[tokenId].issuer
        );
        delete certHashToTokenId[certHash];

        uint256[] storage ownerCerts = ownerCertificates[owner];
        for (uint256 i = 0; i < ownerCerts.length; i++) {
            if (ownerCerts[i] == tokenId) {
                ownerCerts[i] = ownerCerts[ownerCerts.length - 1];
                ownerCerts.pop();
                break;
            }
        }

        _burn(tokenId);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721) returns (address) {
        address from = ownerOf(tokenId);
        require(from == address(0) || to == address(0), "Certificates are non-transferable");
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        require(ownerOf(tokenId) != address(0), "BCERT: token does not exist");
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}