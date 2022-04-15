// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Voting
 * @author Sebastien Gazeau
 * @dev Voting system management
 */
contract Voting is Ownable{
	// Different states of a vote
	enum WorkflowStatus { 
		RegisteringVoters,
		ProposalsRegistrationStarted,
		ProposalsRegistrationEnded,
		VotingSessionStarted,
		VotingSessionEnded,
		VotesTallied
	}
	// block.timestamp<heureFin
	struct Session {
		uint startDate;
		uint startVoting;
		uint endDate;
	}
	struct Voter {
		bool isRegistered;
		bool hasVoted;
		uint votedProposalId;
	}
	struct Proposal {
		string description;
		uint voteCount;
	}
	uint public lastSession;
	mapping(uint => uint[]) public winningProposalsID;
	mapping(uint => Proposal[]) public winningProposals;
	mapping(uint => Session) private listSession;
	mapping(uint => mapping(address => Voter)) private listVoters;
	mapping(uint => Proposal[10]) private listProposals;
	mapping(uint => WorkflowStatus) private listWorkflowStatus;

	/**
	 * @dev Emitted when one voter is added for the voting session
	 */
	event VoterRegistered(uint index, address voterAddress);
	/**
	 * @dev Emitted when multiple voter is added for the voting session
	 */
	event VotersRegistered(uint index, address[] votersAddress);
	/**
	 * @dev Emitted when one voter is excluded for the voting session
	 */
	event VoterExcluded(uint index, address voterAddress);
	/**
	 * @dev Emitted when multiple voter is excluded for the voting session
	 */
	event VotersExcluded(uint index, address[] votersAddress);
	/**
	 * @dev Emitted when a new voting session is created by calling {startVoting}.
	 * `lastSession` is the new last index for voting sessions 
	 */
	event VotingStarted(uint lastSession);
	/**
	 * @dev Emitted when the owner changes the status of the workflow
	 * (from `previousStatus` to `newStatus`) for a voting session `index`.
	 */
	event WorkflowStatusChange(uint index,WorkflowStatus previousStatus, WorkflowStatus newStatus);
	/**
	 * @dev Emitted when a new proposal is created.
	 * `proposalId` is the id of the proposal for voting sessions `index` 
	 */
	event ProposalRegistered(uint index,uint proposalId);
	/**
	 * @dev Emitted when a proposal is deleted.
	 * `proposalId` is the id of the proposal for voting sessions `index` 
	 */
	event ProposalDeleted(uint index,uint proposalId);
	/**
	 * @dev Emitted when a vote is submit.
	 * `proposalId` is the id of the proposal for voting sessions `index`chosose by the `voter`
	 */
	event Voted (uint index,address voter, uint proposalId);

	/**
	 * @dev modifier to check if caller is an authorized voter
	 */ 
	modifier anAuthorizedVoter(uint _index) {
		require(listVoters[_index][msg.sender].isRegistered, "Caller is not authorised");
		_;
	}
	/**
	 * @dev modifier to check if caller can add voters
	 */ 
	modifier inRegisteringStatus(uint _index) {
		require(listWorkflowStatus[_index] == WorkflowStatus.RegisteringVoters, "The registration phase is over");
		_;
	}
	/**
	 * @dev modifier to check if caller can add voters
	 */ 
	modifier inProposalsRegistrationStatus(uint _index) {
		require(listWorkflowStatus[_index] == WorkflowStatus.ProposalsRegistrationStarted, "The previous vote is not over");
		_;
	}

	/**
	 * @dev start voting
	 * @param _session all the dates of the new session
	 * @param _index the voting session index
	 */
	function startVoting(Session calldata _session, uint _index) external onlyOwner {
		require(listSession[_index].startDate == 0, 'the session already exists');
		listSession[_index] = _session;
		lastSession++;
		emit VotingStarted(lastSession);
	}
	/**
	 * @dev Get information for a voting session
	 * @param _index the voting session index
	 * @return session_ information for a voting session
	 */
	function getVotingSession(uint _index) external view returns(Session memory session_){
		return (listSession[_index]);
	}

	/**
	 * @dev change workflow status for a voting session
	 * @param _index the voting session index
	 */
	function nextWorkflowStatus(uint _index) external onlyOwner{
		require (uint(listWorkflowStatus[_index]) != 5, "this session is over");
		require (uint(listWorkflowStatus[_index]) != 4, "start tally votes for this session");
		WorkflowStatus old = listWorkflowStatus[_index];
		listWorkflowStatus[_index]= WorkflowStatus(uint (listWorkflowStatus[_index]) + 1);
		emit WorkflowStatusChange(_index,old, listWorkflowStatus[_index]);
	}

	/****************************************************************************************************/
	/******************************************* Voter Action *******************************************/
	/****************************************************************************************************/
	// :::::::::::::::: SETTERS :::::::::::::::: //
	/**
	 * @dev add a voter
	 * @param _address address to add
	 */
	function voterRegistered(address _address, uint _index) public onlyOwner inRegisteringStatus(_index) {
		listVoters[_index][_address].isRegistered = true;
		emit VoterRegistered(_index,_address);
	}

	/**
	 * @dev add voters
	 * @param _address table of addresses to add
	 * @param _index the voting session index
	 */
	function votersRegistered(address[] memory _address, uint _index)external onlyOwner inRegisteringStatus(_index) {
		for (uint i = 0; i < _address.length; i++){
			listVoters[_index][_address[i]].isRegistered = true;
		}
		emit VotersRegistered(_index,_address);
	}
	/**
	 * @dev exclude a voter
	 * @param _address address to eclude
	 * @param _index the voting session index
	 */
	function voterExcluded(address _address, uint _index) public onlyOwner inRegisteringStatus(_index) {
		listVoters[_index][_address].isRegistered = false;
		emit VoterExcluded(_index,_address);
	}
	/**
	 * @dev exclude voters
	 * @param _address table of addresses to exclude
	 * @param _index the voting session index
	 */
	function votersExcluded(address[] memory _address, uint _index) public onlyOwner inRegisteringStatus(_index){
		for (uint i = 0; i < _address.length; i++){
			listVoters[_index][_address[i]].isRegistered = false;
		}
		emit VotersExcluded(_index,_address);
	}
	// :::::::::::::::: GETTERS ::::::::::::::::::::://
	/**
	 * @dev Get one voter
	 * @param _addressVoter address of a voter
	 * @param _index the voting session index
	 * @return voterReq_ one Voter
	 */
	function getVoter(address _addressVoter, uint _index) external view returns(Voter memory voterReq_){
		// voterReq = listVoters[_index][_addressVoter];
		return (listVoters[_index][_addressVoter]);
	}
	/***************************************************************************************************/
	/***************************************** Proposal Action *****************************************/
	/***************************************************************************************************/
	// :::::::::::::::: SETTER :::::::::::::::: //
	/**
	 * @dev set new proposal
	 * @param _index the voting session index
	 * @param _description a new proposal description
	 */
	function setProposal(uint _index,string memory _description) external inProposalsRegistrationStatus(_index) anAuthorizedVoter(_index){
		require(listProposals[_index].length < 10, "The number of proposals maximal is");
		require(bytes(_description).length > 0, "Proposal is empty");
		listProposals[_index][listProposals[_index].length-1].description = _description;
		emit ProposalRegistered(_index, listProposals[_index].length-1);
	}
	// :::::::::::::::: GETTERS ::::::::::::::::::::://
	/**
	 * @dev Get all proposal
	 * @param _index the voting session index
	 * @param _id identifier of the proposal
	 * @return proposal_ details proposal
	 */
	function getProposal(uint _index, uint _id) external view returns(Proposal memory proposal_) {
		return (listProposals[_index][_id]);
	}
	/**
	 * @dev Get proposals
	 * @param _index the voting session index
	 * @return proposals_ array proposals
	 */
	function getAllProposal(uint _index) external view returns(Proposal[10] memory proposals_){
		return (listProposals[_index]);
	}
	// :::::::::::::::: DELETE ::::::::::::::::::::://
	/**
	 * @dev delete a proposal
	 * @param _index the voting session index
	 * @param _id a new proposal description
	 */
	function deleteProposal(uint _index, uint _id) external onlyOwner inProposalsRegistrationStatus(_index){
		delete listProposals[_index][_id];
		emit ProposalDeleted(_index, _id);
	}
	/***************************************************************************************************/
	/******************************************* Vote Action *******************************************/
	/***************************************************************************************************/
	// :::::::::::::::: SETTER :::::::::::::::: //
	/**
	 * @dev set vote 
	 * @param _index the voting session index
	 * @param _proposalId id of the proposal voted
	 */
	function voted(uint _index, uint _proposalId) external anAuthorizedVoter(_index) {
		require(listWorkflowStatus[_index] == WorkflowStatus.VotingSessionStarted, "you can't vote at the moment");
		require(listVoters[_index][msg.sender].hasVoted == false, "You have already voted");
		listVoters[_index][msg.sender].votedProposalId = _proposalId;
		listVoters[_index][msg.sender].hasVoted = true;
        listProposals[_index][_proposalId].voteCount++;
		emit Voted(_index,msg.sender, _proposalId);
	}

	/**
	 * @dev calcul the winner of the proposal with egality
	 * @param _index the voting session index
	 */
	function tallyVotes(uint _index) external onlyOwner () {
       require(listWorkflowStatus[_index] == WorkflowStatus.VotingSessionEnded, "Current status is not voting session ended");
        uint highestCount;
        uint[5]memory winners; 
        uint nbWinners;
        for (uint i = 0; i < 11; i++) {
            if (listProposals[_index][i].voteCount == highestCount) {
                winners[nbWinners]=i;
                nbWinners++;
            }
            if (listProposals[_index][i].voteCount > highestCount) {
                delete winners;
                winners[0]= i;
                highestCount = listProposals[_index][i].voteCount;
                nbWinners=1;
            }
        }
        for(uint j=0;j<nbWinners;j++){
            winningProposalsID[_index].push(winners[j]);
            winningProposals[_index].push(listProposals[_index][winners[j]]);
        }
        listWorkflowStatus[_index] = WorkflowStatus.VotesTallied;
		emit WorkflowStatusChange(_index,WorkflowStatus.VotingSessionEnded, listWorkflowStatus[_index]);
    }

	/*****************************************************************************************************/
	/*********************************************** Utils ***********************************************/
	/*****************************************************************************************************/	
	/**
	 * @dev exclude voters
	 * @param _i integer to transform into a string
	 * @return str string obtained by the transformation
	 */
	function uint2str(uint256 _i) internal pure returns (string memory str) {
		if (_i == 0) {
			return "0";
		}
		uint256 j = _i;
		uint256 length;
		while (j != 0) {
			length++;
			j /= 10;
		}
		bytes memory bstr = new bytes(length);
		uint256 k = length;
		j = _i;
		while (j != 0) {
			bstr[--k] = bytes1(uint8(48 + j % 10));
			j /= 10;
		}
		str = string(bstr);
	}
}