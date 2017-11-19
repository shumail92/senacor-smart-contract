/*
    Example Smart Contract for Insurance
    @author Shumail Mohyuddin 
 */

pragma solidity ^0.4.0;

contract InsuranceContract {

    enum InsuranceState {
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

    /* address of the insurance owner, for administrative purposes */
    address public insuranceOwner;

    /* mapping for a customer address to Customer Struct */
    mapping (address => Customer) customers;

    /* EVENTS */
    
    event FailedTransaction (
        address from,
        address to,
        int256 amount
    );

    event NewCustomer (
        address customer,
        int256 balance
    );

    event WithdrawByCustomer (
        address customer,
        int balance
    );

    event WithdrawByInsurance (
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
        address customer,
        int requiredAmount,
        int availableAmountInCustomerWallet

    );

    event CustomerCategoryChange (
        address customer,
        DriverCategory previousCategory,
        DriverCategory newCategory
    );

    /*
        Modifiers
    */
    modifier ifFunds(address _to, int tokens) {
        require(customers[msg.sender].balance >= tokens);
        _;
    }

    modifier ifInsuranceOwnerCalling() {
        require(msg.sender == insuranceOwner);
        _;
    }

    modifier ifCustomerIsNew() {
        // quick hack, because this amount will never be 0 for a custome
        require(customers[msg.sender].baseInsuranceAmount != 0);
        _;
    }

    /* Constructor */
    function InsuranceContract() public {
        insuranceOwner = msg.sender;
        customers[insuranceOwner].balance = 100000;
    }

    /* helper function for getting balance */
    function getBalance(address _user) public constant returns (int _balances) {
        return customers[_user].balance;
    }

    /*  
        When a customer registers itself for Insurance 
        by sending some Ether, against which he gets some itnernal tokens 
        @param _crashFreeYeras: Number of yeras since last crash of customer 
        @param _age: Age of customer
        These parameters are used for determining the montly premeium that customer has to pay for insurance    
    */
    function registerCustomer(uint _crashFreeYears, uint _age) ifCustomerIsNew() public payable returns (bool success, address customer) {
        address _customer = msg.sender;
        int _tokens = convertWeiToTokens(msg.value);
        require(_tokens <= customers[insuranceOwner].balance);
        DriverCategory dCat;
        uint premium;
        (dCat, premium) = determineDriverCategoryAndAmount(_crashFreeYears, _age);
        /* set customer category */
        customers[_customer].category = dCat;
        /* Set amount that he has to pay */
        customers[_customer].baseInsuranceAmount = premium;
        
        /* top-up balance of customer as per the ether he sent & deduct those from insurance owner wallet*/
        customers[insuranceOwner].balance -= _tokens;
        customers[_customer].balance += _tokens;

        /* Start his insurance */
        customers[_customer].state = InsuranceState.ACTIVE;
 
        /* Log on blockchain */
        NewCustomer(_customer, _tokens);
        return (true, _customer);
    }

    /* Deduct insurance tokens based upon the score & driver category */
    function deductInsurance(address _customer, uint _score) ifInsuranceOwnerCalling() public returns (bool) {
        /* calculate amount that customer has to pay based on his basic amount & score */
        int amountToPay = customers[_customer].balance + calculatePenaltyFromScore(_score);

        /* Only process if customer has enough tokens & his insurance is ACTIVE */
        if (customers[_customer].balance >= amountToPay && customers[_customer].state == InsuranceState.ACTIVE ) {
            /* transfer tokens from customer to insurance owner */
            customers[_customer].balance -= amountToPay;
            customers[insuranceOwner].balance += amountToPay;
            /* Save most recent score of customer */
            customers[_customer].score = _score;
            /* Log the event. This will also prepare history of customer */
            InsuranceTransaction(_customer, amountToPay, _score); // log customer, insurance amount, and score
            return true;
        } else {
            /* If not enough balance, make insurance INACTIVE */
            customers[_customer].state = InsuranceState.INACTIVE;
            FailedInsuranceTransaction(_customer, amountToPay, customers[_customer].balance);
            return false;
        }
    }

    /* topup account if balance low or zero */
    function topupAccount() public payable returns (bool, int) {
        require(customers[msg.sender].state != InsuranceState.WITHDRAWN);
        int tokens = convertWeiToTokens(msg.value);
        /* transfer tokens from insurance wallet to customer */
        customers[insuranceOwner].balance -= tokens;
        customers[msg.sender].balance += tokens;
        TopupAccount(msg.sender, tokens);
        return (true, customers[msg.sender].balance);
    }
    /* 
        if customer withdraws from insurance, make insurance INACTIVE and transfer remaining tokens
        to Insurance wallet. Remaining tokens should be refunded to custoemr in form of ether. 
    */
    function withdrawByCustomer() public returns (bool, int) {
        require(customers[msg.sender].state != InsuranceState.WITHDRAWN);
        customers[msg.sender].state = InsuranceState.WITHDRAWN;
        int currentBalanceBeforeWithdraw = customers[msg.sender].balance;
        customers[insuranceOwner].balance += currentBalanceBeforeWithdraw;
        customers[msg.sender].balance = 0;
        WithdrawByCustomer(msg.sender, currentBalanceBeforeWithdraw);
        return (true, currentBalanceBeforeWithdraw);
    }

    function changeCustomerDrivingCategory(address customer, uint enumIndex) ifInsuranceOwnerCalling() {
        require(customers[msg.sender].state == InsuranceState.ACTIVE);
        DriverCategory previousCategory = customers[msg.sender].category;
        if (enumIndex == 0) {
            customers[msg.sender].category = DriverCategory.NAIVE;    
        } else if (enumIndex == 1) {
            customers[msg.sender].category = DriverCategory.INTERMEDIATE;
        } else if (enumIndex == 2) {
            customers[msg.sender].category = DriverCategory.EXPERT;
        }
        CustomerCategoryChange(customer, previousCategory, customers[msg.sender].category);
    }
    /* If for some reason insurance company terminates the contract. Refund remaining tokens too */
    function withdrawByInsurance(address _customer) public ifInsuranceOwnerCalling() returns (bool, int) {
        require(customers[_customer].state != InsuranceState.WITHDRAWN);
        customers[_customer].state = InsuranceState.WITHDRAWN;
        int currentBalanceBeforeWithdraw = customers[_customer].balance;
        customers[insuranceOwner].balance += currentBalanceBeforeWithdraw;
        customers[_customer].balance = 0;
        WithdrawByInsurance(_customer, currentBalanceBeforeWithdraw);
        return (true, currentBalanceBeforeWithdraw);
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

    function convertWeiToTokens(uint weiReceived) pure returns (int _tokens) {
        // 1€ = 1 token  = 3333333300000000 wei
        int tokens = int(weiReceived / 3333333300000000);
        return tokens;
    }
}

/* TODOS:
 - put mistakes on chain ?
 - changeCategory() // based on crash
 - optimize
 - add modifier for insuranceOwnerCalls only
 - update crashFreeYears & Category of driver based on history
 
DONE
- implement tiers of payment for score. 0-35, 35-70, >70
    -factor of 2.
- category of driver & diff pricing
- determine amount to charge based on score
- withdraw insurance
- make payable function, get ether & fund tokens?
- any possibility of getting rid of _customer address in calls?
*/
