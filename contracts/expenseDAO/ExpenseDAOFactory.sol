// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExpenseDAO.sol";
import "./Registry.sol";

contract ExpenseDAOFactory {
  Registry public registry;
  address private co2Token;

  constructor(Registry reg, address co2TokenAddress) {
    registry = reg;
    co2Token = co2TokenAddress;
  }

  function newExpenseOrg(
    string calldata name,
    address stableCoin,
    address[] calldata approvers,
    address[] calldata members)
    external returns (ExpenseDAO r) {

    r = new ExpenseDAO(stableCoin, co2Token, approvers, members);
    registry.register(name, r, msg.sender);
  }
}


Tron Nile testnet
registry
base58 TDVhs8p4RuzndoKUYddwTju4neM2x6RQE9
hex 4126ACF33CE37632FA2B55750D6B8AA84E5E16AA67


co2
base58 TAFyAwZraAqcfQoEDfU2sMzA6AsPp6DNtR
hex 41032B86E7B97B49CE54AEF87087F208B676BC622D

expenseDAO factory
base58 TA34rk621RTu1Ccm33if4moP9SdxgLteRB
hex 4100baddb925361fabd9eea614c18cf3dde08333a4



55df3bf2d78674e489c07eb902eff44b7a81c157

tron firefox wallet: stove fossil camera vague canoe health east bounce rule wonder ugly fun
