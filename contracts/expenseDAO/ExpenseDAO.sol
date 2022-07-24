// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AccessControlEnumerable.sol";
import "./ReentrancyGuard.sol";
import "../TRC20.sol";
import "../Token.sol";


contract ExpenseDAO is ReentrancyGuard, AccessControlEnumerable {
  // User roles.
  bytes32 public constant MEMBER_ROLE = keccak256("MEMBER");
  bytes32 public constant APPROVER_ROLE = keccak256("APPROVER");

  uint256 private numOfRequests;
  uint256 private deniedRequests;
  uint256 private approvedRequests;
  uint256 private paidOut;
  uint256 private totalCO2;
  uint256 private pendingCO2;

  address public stableCoinAddress;
  address public CO2TokenAddress;

  struct ReimbursementRequest {
    uint256 id;
    uint256 amount;
    uint256 date;
    uint256 co2;
    uint8 category;
    bool processed;
    bool approved;
    bool paid;
    address payable reimbursementAddress;
    address member;
    address paidBy;
    string description;
    string url;
  }

  mapping(uint256 => ReimbursementRequest) private reimbursementRequests;
  mapping(address => uint256[]) private memberRequests;
  mapping(uint8 => uint256) private categoryCounters;

  // Events.
  event NewRequestCreated(address indexed member, uint256 amount);
  event PaymentTransfered(
    address indexed approver,
    address indexed reimbursementAddress,
    uint256 amount);

  event BalanceIncreased(address indexed fromAddress, uint256 amount);

  // Modifiers.
  modifier onlyApprover(string memory message) {
    require(hasRole(APPROVER_ROLE, msg.sender), message);
    _;
  }

  modifier onlyMember(string memory message) {
    require(hasRole(MEMBER_ROLE, msg.sender), message);
    _;
  }

  modifier memberOrApprover(string memory message) {
    require(hasRole(MEMBER_ROLE, msg.sender) ||
      hasRole(APPROVER_ROLE, msg.sender), message);
    _;
  }

  // Constructor.
  constructor(
    address stableToken,
    address co2Token,
    address[] memory approvers,
    address[] memory members) {
    
    // Set stable token address. Usually, it would be either cUSD or cEUR.
    stableCoinAddress = stableToken;
    // Set carbon credit token address.
    CO2TokenAddress = co2Token;

    require(approvers.length > 1,
      "At least two approver addresses must be provided");
    for (uint256 i = 0; i < approvers.length; i++) {
      _setupRole(APPROVER_ROLE, approvers[i]);
      _setupRole(DEFAULT_ADMIN_ROLE, approvers[i]);
    }

    for (uint256 i = 0; i < members.length; i++) {
      _setupRole(MEMBER_ROLE, members[i]);
    }
  }

  // Creates new reimbursement request. Only members and approvers are allowed
  // to call this function.
  function createRequest(
    string calldata description,
    string calldata url,
    address reimbursementAddress,
    uint256 amount,
    uint256 date,
    uint256 co2Amount,
    uint8 category)
    external
    memberOrApprover("You are not allowed to create requests") {

    uint256 requestId = numOfRequests++;

    categoryCounters[category]++;
    pendingCO2 += co2Amount;

    ReimbursementRequest storage request = reimbursementRequests[requestId];
    request.id = requestId;
    request.amount = amount;
    request.category = category;
    request.co2 = co2Amount;
    request.date = date;
    request.description = description;
    request.url = url;
    request.reimbursementAddress = payable(reimbursementAddress);
    request.member = msg.sender;

    memberRequests[request.member].push(requestId);

    emit NewRequestCreated(msg.sender, amount);
  }

  // Used to approve or deny a request. Can be called by approvers only.
  function processRequest(uint256 requestId, bool approved)
    external
    onlyApprover("Only approvers are allowed to process requests") {

    ReimbursementRequest storage request = reimbursementRequests[requestId];
    require(msg.sender != request.member,
      "An Approver is not allowed to process its own requests");

    preProcess(request);
    request.approved = approved;
    if (request.approved) {
      approvedRequests++;
      payRequest(request);
    } else {
      deniedRequests++;
    }

  }

  // Checks preconditions.
  function preProcess(ReimbursementRequest storage request) private {
    if (request.processed || request.paid) {
      revert("Reimbursement request has been processed already");
    }
    request.processed = true;
  }

  // Transfers requested amount to reimbursement address.
  function payRequest(ReimbursementRequest storage request) private {
    if (request.paid) {
      revert("Reimbursement request has been paid already");
    }
    if (!request.approved) {
      revert("Reimbursement request has been denied already");
    }
    request.paid = true;
    request.paidBy = msg.sender;
    paidOut += request.amount;

    emit PaymentTransfered(
      msg.sender,
      request.reimbursementAddress,
      request.amount);

    bool success = TRC20(stableCoinAddress).transfer(
      request.reimbursementAddress,
      request.amount);
    require(success);
    // return request.reimbursementAddress.transfer(request.amount);
  }

  // Used to increase balance of the contract.
  receive() external payable {
    emit BalanceIncreased(msg.sender, msg.value);
  }

  // Returns whether the sender has a member role.
  function isMember() public view returns (bool) {
    return hasRole(MEMBER_ROLE, msg.sender);
  }

  // Returns whether the sender has an approver role.
  function isApprover() public view returns (bool) {
    return hasRole(APPROVER_ROLE, msg.sender);
  }

  // Returns all relevant info about the organization.
  function getSummary() public view returns (
    uint256 requestsNum,
    uint256 approvedNum,
    uint256 deniedNum,
    uint256 category1,
    uint256 category2,
    uint256 category3,
    uint256 category4,
    uint256 category5,
    uint256 category6,
    uint256 paidTotal,
    uint256 CO2Pending,
    uint256 CO2Total
   ) {
    requestsNum = numOfRequests;
    approvedNum = approvedRequests;
    deniedNum = deniedRequests;
    category1 = categoryCounters[1];
    category2 = categoryCounters[2];
    category3 = categoryCounters[3];
    category4 = categoryCounters[4];
    category5 = categoryCounters[5];
    category6 = categoryCounters[6];
    paidTotal = paidOut;
    CO2Pending = pendingCO2;
    CO2Total = totalCO2;
  }

  // Returns all the reimbursement requests for the caller.
  function getMembersRequests()
    public
    view
    returns (ReimbursementRequest[] memory requests) {

    uint256 size = memberRequests[msg.sender].length;
    requests = new ReimbursementRequest[](size);
    for (uint256 index = 0; index < size; index++) {
      requests[index] =
        reimbursementRequests[memberRequests[msg.sender][index]];
    }
  }

  // Returns all the reimbursement requests.
  function getRequests()
    public
    view
    returns (ReimbursementRequest[] memory requests) {
    
    requests = new ReimbursementRequest[](numOfRequests);
    for (uint256 index = 0; index < numOfRequests; index++) {
      requests[index] = reimbursementRequests[index];
    }
  }

  // Returns a particular reimbursement request for provided id.
  function getRequest(uint256 requestId)
    public
    view
    returns (ReimbursementRequest memory) {

    return reimbursementRequests[requestId];
  }

  // Returns a list of members.
  function getMembers()
    public
    view
    returns (address[] memory members) {

    uint256 membersCount = getRoleMemberCount(MEMBER_ROLE);
    members = new address[](membersCount);

    for (uint256 index = 0; index < membersCount; index++) {
      members[index] = getRoleMember(MEMBER_ROLE, index);
    }
  }

  // Returns a list of approvers.
  function getApprovers()
    public
    view
    returns (address[] memory approvers) {

    uint256 approversCount = getRoleMemberCount(APPROVER_ROLE);
    approvers = new address[](approversCount);

    for (uint256 index = 0; index < approversCount; index++) {
      approvers[index] = getRoleMember(APPROVER_ROLE, index);
    }
  }

  // Adds new member.
  function addMember(address member)
  external
  onlyApprover("Only approver can add new members") {
    _setupRole(MEMBER_ROLE, member);
  }

  // Removes existing member.
  function removeMember(address member)
  external
  onlyApprover("Only approver can remove members") {
    _revokeRole(MEMBER_ROLE, member);
  }

  function compensateCO2()
  external
  onlyApprover("Only approver can offset carbon credits") {
    Token(CO2TokenAddress).burn(pendingCO2);
    totalCO2 += pendingCO2;
    pendingCO2 = 0;
  }
}
