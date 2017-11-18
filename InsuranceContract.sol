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

    enum DriverCategory {
        NAIVE,
        INTERMEDIATE,
        EXPERT
    }

    struct Customer {
        int balance;
        uint score;
        uint baseInsuranceAmount;
        DriverCategory category;
        InsuranceState state;
    }

    uint counter;
    address public insuranceOwner;
    mapping (address => Customer) customers;

    event FailedTransaction (
        address from,
        address to,
        int256 amount
    );

    event NewCustomer (
        address customer,
        int256 balance
    );

    event WithdrawCustomer (
        address customer,
        int balance
    );

    event InsuranceTransaction (
        address customer,
        int256 tokens,
        uint256 score
    );

    event TopupAccount (
        address customer,
        int256 tokens
    );

    event FailedInsuranceTransaction (
        address _customer,
        int _requiredAmount,
        int _availableAmountInCustomerWallet

    );

    modifier ifFunds(address _to, int tokens) {
        require(customers[msg.sender].balance >= tokens);
        _;
    }

    modifier ifInsuranceOwnerCalling() {
        require(msg.sender == insuranceOwner);
        _;
    }

    function InsuranceContract() public {
        counter = 0;
        insuranceOwner = msg.sender;
        customers[insuranceOwner].balance = 100000;
    }

    function getBalance(address _user) public constant returns (int _balances) {
        return customers[_user].balance;
    }

    /* When a customer buys insurance, we topup his acount with those number of tokens */ //todo: modifier onlyInsurance
    function registerCustomer(address _customer, int _tokens, uint _crashFreeYears, uint _age) ifInsuranceOwnerCalling() ifFunds(_customer, _tokens) public returns (bool success, address customer) {
        DriverCategory dCat;
        uint premium;
        (dCat, premium) = determineDriverCategoryAndAmount(_crashFreeYears, _age);
        customers[_customer].category = dCat;
        customers[_customer].baseInsuranceAmount = premium;
        customers[msg.sender].balance -= _tokens;
        customers[_customer].balance += _tokens;
        customers[_customer].state = InsuranceState.CREATED;
        NewCustomer(_customer, _tokens);
        return (true, _customer);
    }

    /* Deduct insurance tokens based upon the score & driver category */ //todo: modifier onlyInsurance
    function deductInsurance(address _customer, uint _score) ifInsuranceOwnerCalling() public returns (bool) {
        // calculate tokens to deduct based on the score
        int amountToPay = customers[_customer].balance + calculatePenaltyFromScore(_score);
        if (customers[_customer].balance >= amountToPay && customers[_customer].state == InsuranceState.ACTIVE ) {
            customers[_customer].balance -= amountToPay;
            customers[_customer].score = _score;
            InsuranceTransaction(_customer, amountToPay, _score); // log customer, insurance amount, and score
            return true;
        } else {
            customers[_customer].state = InsuranceState.INACTIVE;
            FailedInsuranceTransaction(_customer, amountToPay, customers[_customer].balance);
            return false;
        }
    }

    /* topup account if balance low or zero */ //todo: modifier onlyInsurance
    function topupAccount(address _customer, int tokens) ifInsuranceOwnerCalling() public returns (bool, int) {
        if (customers[_customer].state != InsuranceState.WITHDRAWN ) {
            customers[msg.sender].balance -= tokens;
            customers[_customer].balance += tokens;
            TopupAccount(_customer, tokens);
            return (true, customers[_customer].balance);
        } else {
            return (false, customers[_customer].balance);
        }
    }

    function withdraw(address _customer) ifInsuranceOwnerCalling() public returns (bool, int) {
        if (customers[_customer].state != InsuranceState.WITHDRAWN) {
            customers[_customer].state = InsuranceState.WITHDRAWN;
            int currentBalanceBeforeWithdraw = customers[_customer].balance;
            customers[insuranceOwner].balance += currentBalanceBeforeWithdraw;
            customers[_customer].balance = 0;
            return (true, currentBalanceBeforeWithdraw);
            WithdrawCustomer(_customer, currentBalanceBeforeWithdraw);
        } else {
            return (false, 0);
        }
    }

    function determineDriverCategoryAndAmount(uint crashFreeYears, uint ageOfDriver) internal pure returns (DriverCategory cat, uint insuranceAmount) {
        if (crashFreeYears == 0) {
            return (DriverCategory.NAIVE, 10);
        } else if (crashFreeYears > 0 && crashFreeYears <= 5 ) {
            return (DriverCategory.INTERMEDIATE, 8);
        } else if (crashFreeYears > 5) {
            return (DriverCategory.EXPERT, 6);
        }
        /* todo: add rules based upon driver age */
    }

    function calculatePenaltyFromScore(uint score) internal pure returns (int penalty) {
        if ( score >= 0 && score <= 35 ) {  // bad driving
            return 2;
        } else if ( score > 35 && score <= 70 ) {
            return 0;
        } else if ( score > 70 ) { // good score,
            return -2; // pay less because you drove good.
        }
    }

    /* Util functions */
    
    function generateAddress(uint _id) internal pure returns (bytes32 a) {
        return keccak256(_id);
    }

    function getID() internal returns(uint) { 
        return ++counter; 
    }
}

/* TODOS:
 - withdraw insurance
 - changeCategory() // based on crash
 - any possibility of getting rid of _customer address in calls?

 - update crashFreeYears & Category of driver based on history
 - optimize
 - add modifier for insuranceOwnerCalls only

DONE
- implement tiers of payment for score. 0-35, 35-70, >70
    -factor of 2.
- category of driver & diff pricing
- determine amount to charge based on score

*/
