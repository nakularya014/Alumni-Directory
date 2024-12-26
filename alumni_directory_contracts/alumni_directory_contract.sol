// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AlumniDirectory {
    // Alumni Profile Structure
    struct AlumniProfile {
        uint256 id;
        string name;
        string email;
        string graduationYear;
        string department;
        string currentPosition;
        string company;
        string location;
        string[] skills;
        address walletAddress;
        bool isVerified;
    }

    // Connection Request Structure
    struct ConnectionRequest {
        uint256 fromProfileId;
        uint256 toProfileId;
        RequestStatus status;
    }

    // Enum for Connection Request Status
    enum RequestStatus {
        Pending,
        Accepted,
        Rejected
    }

    // Events for Transparency
    event ProfileCreated(uint256 indexed profileId, string name, string email);
    event ProfileUpdated(uint256 indexed profileId, string name);
    event ConnectionRequested(uint256 indexed fromProfileId, uint256 indexed toProfileId);
    event ConnectionAccepted(uint256 indexed fromProfileId, uint256 indexed toProfileId);

    // Contract Management
    address public owner;
    uint256 public profileCount;
    uint256 public connectionRequestCount;

    // Mappings for Data Management
    mapping(uint256 => AlumniProfile) public profiles;
    mapping(address => uint256) public addressToProfileId;
    mapping(uint256 => uint256[]) public alumniConnections;
    mapping(uint256 => ConnectionRequest) public connectionRequests;
    mapping(uint256 => mapping(uint256 => bool)) public isConnected;

    // Verification Management
    mapping(uint256 => bool) public verificationRequests;
    uint256[] public pendingVerifications;

    constructor() {
        owner = msg.sender;
    }

    // Modifiers for Access Control
    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyProfileOwner(uint256 _profileId) {
        require(profiles[_profileId].walletAddress == msg.sender, "Only profile owner can modify");
        _;
    }

    // Profile Creation and Management
    function createProfile(
        string memory _name,
        string memory _email,
        string memory _graduationYear,
        string memory _department,
        string memory _currentPosition,
        string memory _company,
        string memory _location,
        string[] memory _skills
    ) external returns (uint256) {
        // Prevent duplicate profiles
        require(addressToProfileId[msg.sender] == 0, "Profile already exists");

        profileCount++;
        
        AlumniProfile storage newProfile = profiles[profileCount];
        newProfile.id = profileCount;
        newProfile.name = _name;
        newProfile.email = _email;
        newProfile.graduationYear = _graduationYear;
        newProfile.department = _department;
        newProfile.currentPosition = _currentPosition;
        newProfile.company = _company;
        newProfile.location = _location;
        newProfile.skills = _skills;
        newProfile.walletAddress = msg.sender;
        newProfile.isVerified = false;

        addressToProfileId[msg.sender] = profileCount;

        emit ProfileCreated(profileCount, _name, _email);
        return profileCount;
    }

    // Update Profile
    function updateProfile(
        uint256 _profileId,
        string memory _currentPosition,
        string memory _company,
        string memory _location,
        string[] memory _skills
    ) external onlyProfileOwner(_profileId) {
        AlumniProfile storage profile = profiles[_profileId];
        
        profile.currentPosition = _currentPosition;
        profile.company = _company;
        profile.location = _location;
        profile.skills = _skills;

        emit ProfileUpdated(_profileId, profile.name);
    }

    // Connection Request Functionality
    function requestConnection(uint256 _fromProfileId, uint256 _toProfileId) external {
        require(_fromProfileId != _toProfileId, "Cannot connect to self");
        require(profiles[_fromProfileId].walletAddress == msg.sender, "Unauthorized connection request");
        require(!isConnected[_fromProfileId][_toProfileId], "Already connected");

        connectionRequestCount++;
        
        connectionRequests[connectionRequestCount] = ConnectionRequest({
            fromProfileId: _fromProfileId,
            toProfileId: _toProfileId,
            status: RequestStatus.Pending
        });

        emit ConnectionRequested(_fromProfileId, _toProfileId);
    }

    // Accept Connection Request
    function acceptConnection(uint256 _requestId) external {
        ConnectionRequest storage request = connectionRequests[_requestId];
        require(
            profiles[request.toProfileId].walletAddress == msg.sender, 
            "Only recipient can accept"
        );
        require(request.status == RequestStatus.Pending, "Request not pending");

        // Update connection status
        request.status = RequestStatus.Accepted;
        isConnected[request.fromProfileId][request.toProfileId] = true;
        isConnected[request.toProfileId][request.fromProfileId] = true;

        // Add to connections list
        alumniConnections[request.fromProfileId].push(request.toProfileId);
        alumniConnections[request.toProfileId].push(request.fromProfileId);

        emit ConnectionAccepted(request.fromProfileId, request.toProfileId);
    }

    // Verification Request
    function requestVerification(uint256 _profileId) external onlyProfileOwner(_profileId) {
        require(!profiles[_profileId].isVerified, "Profile already verified");
        require(!verificationRequests[_profileId], "Verification already requested");

        verificationRequests[_profileId] = true;
        pendingVerifications.push(_profileId);
    }

    // Verify Profile (Only Owner)
    function verifyProfile(uint256 _profileId) external onlyOwner {
        require(verificationRequests[_profileId], "No verification request");
        
        profiles[_profileId].isVerified = true;
        verificationRequests[_profileId] = false;

        // Remove from pending verifications
        for (uint256 i = 0; i < pendingVerifications.length; i++) {
            if (pendingVerifications[i] == _profileId) {
                pendingVerifications[i] = pendingVerifications[pendingVerifications.length - 1];
                pendingVerifications.pop();
                break;
            }
        }
    }

    // View Functions
    function getProfile(uint256 _profileId) external view returns (AlumniProfile memory) {
        return profiles[_profileId];
    }

    function getConnectionRequests(uint256 _profileId) external view returns (ConnectionRequest[] memory) {
        ConnectionRequest[] memory requests = new ConnectionRequest[](connectionRequestCount);
        uint256 count = 0;

        for (uint256 i = 1; i <= connectionRequestCount; i++) {
            if (connectionRequests[i].toProfileId == _profileId) {
                requests[count] = connectionRequests[i];
                count++;
            }
        }

        return requests;
    }

    function getAlumniConnections(uint256 _profileId) external view returns (uint256[] memory) {
        return alumniConnections[_profileId];
    }

    // Search and Filter Functions
    function searchAlumniByDepartment(string memory _department) external view returns (uint256[] memory) {
        uint256[] memory matchingProfiles = new uint256[](profileCount);
        uint256 count = 0;

        for (uint256 i = 1; i <= profileCount; i++) {
            if (keccak256(bytes(profiles[i].department)) == keccak256(bytes(_department))) {
                matchingProfiles[count] = i;
                count++;
            }
        }

        // Resize array to actual matches
        uint256[] memory result = new uint256[](count);
        for (uint256 j = 0; j < count; j++) {
            result[j] = matchingProfiles[j];
        }

        return result;
    }

    function searchAlumniBySkill(string memory _skill) external view returns (uint256[] memory) {
        uint256[] memory matchingProfiles = new uint256[](profileCount);
        uint256 count = 0;

        for (uint256 i = 1; i <= profileCount; i++) {
            for (uint256 j = 0; j < profiles[i].skills.length; j++) {
                if (keccak256(bytes(profiles[i].skills[j])) == keccak256(bytes(_skill))) {
                    matchingProfiles[count] = i;
                    count++;
                    break;
                }
            }
        }

        // Resize array to actual matches
        uint256[] memory result = new uint256[](count);
        for (uint256 j = 0; j < count; j++) {
            result[j] = matchingProfiles[j];
        }

        return result;
    }
}