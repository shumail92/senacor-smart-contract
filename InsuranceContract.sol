/*
    Example Smart Contract for Insurance
    @author Shumail Mohyuddin 
 */

pragma solidity ^0.4.0;

contract InsuranceContract {

    enum InsuranceState {
        CREATED,
        ACTIVE,
        INACTIVE,
        WITHDRAWN
    }

    struct Customer {
        uint balance;
        uint score;
        InsuranceState state;
    }

    uint counter;
    address public insuranceOwner;
    mapping (address => Customer) customers;

    event FailedTransaction (
        address _from,
        address _to,
        uint256 _amount
    );

    event NewCustomer (
        address _customer,
        uint256 _balance
    );

    event InsuranceTransaction (
        address _customer,
        uint256 _value,
        uint256 _score
    );

    event TopupAccount (
        address _customer,
        uint256 _value
    );

    event FailedInsuranceTransaction (
        address _customer,
        uint _requiredAmount,
        uint _availableAmountInCustomerWallet

    );

    modifier ifFunds(address _to, uint _value) {
        if (customers[msg.sender].balance <= _value) {
            FailedTransaction(msg.sender, _to, _value);
            throw;
        }
        _;
    }

    function InsuranceContract() {
        counter = 0;
        insuranceOwner = msg.sender;
        customers[insuranceOwner].balance = 100000;
    }

    function getBalance(address _user) constant returns (uint _balances) {
        return customers[_user].balance;
    }

    /* When a customer buys insurance, we topup his acount with those number of tokens */
    function buyInsurance(uint _value) ifFunds(_customer, _value) returns (bool success, address customer) {
        address _customer = generateAddress(getID());
        customers[msg.sender].balance -= _value;
        customers[_customer].balance += _value;
        customers[_customer].state = InsuranceState.CREATED;
        NewCustomer(_customer, _value);
        return (true, _customer);
    }

    /* Deduct insurance tokens based upon the score */
    function deductInsurance(address _customer, uint _value, uint _score) returns (bool) {
        if (customers[_customer].balance >= _value && customers[_customer].state == InsuranceState.ACTIVE ) {
            customers[_customer].balance -= _value;
            customers[_customer].score = _score;
            InsuranceTransaction(_customer, _value, _score); // log customer, insurance amount, and score
            return true;
        } else {
            customers[_customer].state = InsuranceState.INACTIVE;
            FailedInsuranceTransaction(_customer, _value, customers[_customer].balance);
            return false;
        }
    }

    function topupAccount(address _customer, uint _value) returns (uint) {
        customers[msg.sender].balance -= _value;
        customers[_customer].balance += _value;
        TopupAccount(_customer, _value);
        return customers[_customer].balance;
    }

    function generateAddress(uint _id) returns (address a) {
        return bytesToAddress(keccak256(_id));
    }

    function bytesToAddress (bytes b) constant returns (address) {
    uint result = 0;
    for (uint i = 0; i < b.length; i++) {
        uint c = uint(b[i]);
        if (c >= 48 && c <= 57) {
            result = result * 16 + (c - 48);
        }
        if (c >= 65 && c <= 90) {
            result = result * 16 + (c - 55);
        }
        if (c >= 97 && c <= 122) {
            result = result * 16 + (c - 87);
        }
    }
    return address(result);
}

    function getID() returns(uint) { 
        return ++counter; 
    }
}

/* TODOS:
 - topup function
 - generate address automatically by ID
 - add check for enough balance & change insurance state

*/
