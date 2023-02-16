// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Take care of differents roles
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DAO is ReentrancyGuard, AccessControl {
    // Byte hash data
    bytes32 private immutable CONTRIBUTOR_ROLE = keccak256("CONTRIBUTOR");
    bytes32 private immutable STAKEHOLDER_ROLE = keccak256("STAKEHOLDER");

    uint256 immutable MIN_STAKEHOLDER_CONTRIBUTION = 1 ether;
    uint32 immutable MIN_VOTE_DURATION = 3 minutes;

    uint32 totalProposals;
    uint256 public daoBalance;

    // Store all raised proposal
    mapping(uint256 => ProposalStruct) private raisedProposals;
    // Vote given by individual stakeholder to a specific proposal
    mapping(address => uint256[]) private stakeholderVotes;
    mapping(uint256 => VotedStruct[]) private votedOn;
    mapping(address => uint256) private contributors;
    mapping(address => uint256) private stakeholders;

    struct ProposalStruct {
        uint256 id;
        uint256 amount;
        uint256 duration;
        uint256 upvotes;
        uint256 downvotes;
        string title;
        string description;
        bool passed;
        bool paid;
        address payable beneficiary;
        address proposer;
        address executor;
    }

    struct VotedStruct {
        address voter;
        uint256 timestamp;
        bool chosen;
    }

    event Action(
        address indexed initiator,
        bytes32 role, // Contributor or Stakeholder role
        string message,
        address indexed beneficiary,
        uint256 amount
    );

    modifier stakeholderOnly(string memory message) {
        require(hasRole(STAKEHOLDER_ROLE, msg.sender), message);
        _;
    }

    modifier contributorOnly(string memory message) {
        require(hasRole(CONTRIBUTOR_ROLE, msg.sender), message);
        _;
    }

    function createProposal(
        string memory title,
        string memory description,
        address beneficiary,
        uint256 amount
    )
        external
        stakeholderOnly("Proposal creation allowed for the stakeholders only")
    {
        uint32 proposalId = totalProposals++;
        ProposalStruct storage proposal = raisedProposals[proposalId];

        proposal.id = proposalId;
        proposal.proposer = payable(msg.sender);
        proposal.title = title;
        proposal.description = description;
        proposal.beneficiary = payable(beneficiary);
        proposal.amount = amount;
        proposal.duration = block.timestamp + MIN_VOTE_DURATION;

        emit Action(
            msg.sender,
            STAKEHOLDER_ROLE,
            "PROPOSAL RAISED",
            beneficiary,
            amount
        );
    }

    function handleVoting(ProposalStruct storage proposal) private {
        if (proposal.passed || proposal.duration <= block.timestamp) {
            proposal.passed = true;
            revert("Proposal duration expired");
        }

        uint256[] memory tempVotes = stakeholderVotes[msg.sender];
        for (uint256 votes = 0; votes < tempVotes.length; votes++) {
            if (proposal.id == tempVotes[votes]) {
                revert("Double voting not allowed");
            }
        }

        function vote(uint256 proposalId, bool chosen) 
        external stakeholderOnly("Unauthorized access: Stakeholder only permitted") 
        returns(VotedStruct memory) {
            ProposalStruct storage proposal = raisedProposals[proposalId];
            handleVoting(proposal);

            if(chosen) {
                proposal.upvotes++;
            } else {
                proposal.downvotes++;
            }

            stakeholderVotes[msg.sender].push(proposalId);
            VotedOn[proposal.id].push(
                VotedStruct(
                    msg.sender,
                    block.timestamp,
                    chosen
                )
            );

            emit Action(
                msg.sender,
                STAKEHOLDER_ROLE,
                "PROPOSAL VOTE",
                proposal.beneficiary,
                proposal.amount
            );

            return VotedStruct(
                msg.sender,
                block.timestamp,
                chosen
            );
        }
    }

    // Pay particular amount to a receiver address
    function payTo(address to, uint amount) internal returns(bool) {
        (bool success,) = payable(to).call[value:amount]("");
        require(success, "Payment Failedn something went wrong");

        return true;
    }

    function payBeneficiary(uint proposalId) 
    public stakeholderOnly("Unauthorizes: Stakeholders Only")
    nonReentrant returns(uint) {
        ProposalSruct storage proposal = raisedProposals[proposalId];
        require(daoBalance >= proposal.amount, "Insufficient funds");

        if(proposal.paid) {
            revert("Payment is already sent");
        }

        if(proposal.upvotes <= proposal.downvotes) {
            revert("Insufficient Votes");
        }

        proposal.paid = true;
        proposal.executor = msg.sender;
        daoBalance -= proposal.amount;

        payTo(proposal.beneficiary, proposal.amount);

        emit Action(
            msg.sender,
            STAKEHOLDER_ROLE,
            "PAYMENT TRANSFERRED",
            proposal.beneficiary,
            proposal.amount
        );

        return daoBalance;
    }

    // Receiving money for the proposal
    function contribute() public payable {
        require(msg.value > 0, "Contribution should be more than 0");

        if(!hasRole(STAKEHOLDER_ROLE, msg.sender)) {
            uint256 totalContribution = contributors[msg.sender] + msg.value;

            if(totalContribution >= MIN_STAKEHOLDER_CONTRIBUTION) {
                stakeholders[msg.sender] = totalContribution;
                _grantRole(STAKEHOLDER_ROLE, msg.sender);
            }
            contributors[msg.sender] += msg.value;
            _grantRole(CONTRIBUTOR_ROLE, msg.sender);
        } else {
            contributors[msg.sender] += msg.value;
            stakeholders[msg.sender] += msg.value;
        }

        // Update Smart Contract Balance
        daoBalance += msg.value;

        emit Action(
            msg.sender,
            CONTRIBUTOR_ROLE,
            "CONTRIBUTION RECEIVED",
            address(this),
            msg.value
        );
    }

    function getProposals() external view returns(ProposalStruct[] memory) {
        props = new ProposalStruct[](totalProposals);

        for(uint256 i = 0; i < totalProposals; i++) {
            props[i] = raisedProposals[i];
        }
    }

    function getProposal(uint256 proposalId) public view returns(ProposalStruct memory) {
        return raiseProposals[proposalId];
    }

    function getVotesOf(uint256 proposalId) public view returns(VotedStruct[] memory) {
        return votedOn[proposalId];
    }

    function getStakeHolderVotes() 
    external view stakeholderOnly("Unauthorized: not a stakeholder") returns(uint256[] memory) {
        return stakeholderVotes[msg.sender];
    }

    function getStakeholderBalance() 
    external view stakeholderOnly("Unauthorized: not a stakeholder") returns(uint256) {
        return stakeholders[msg.sender];
    }
}
