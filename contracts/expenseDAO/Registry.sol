// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExpenseDAO.sol";

contract Registry {
  event NewOrganizationRegistered(
    ExpenseDAO indexed organization, address indexed createdBy, string name);
  mapping(string => address) public organizations;

  function register(
    string calldata name,
    ExpenseDAO newOrganization,
    address createdBy) external {

    require(organizations[name] == address(0), "Name already in use");
    organizations[name] = address(newOrganization);
    emit NewOrganizationRegistered(newOrganization, createdBy, name);
  }

}