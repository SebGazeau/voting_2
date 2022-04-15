const Voting = artifacts.require('Voting');
// @ts-ignore
import { BN, expectRevert, expectEvent } from '@openzeppelin/test-helpers';
import { expect } from 'chai';
import { VotingInstance } from '../types/truffle-contracts';
import { AllEvents } from '../types/truffle-contracts/Voting';
import { Account } from './utils/type/Account';
import { Session } from './utils/type/Session';
import { Voter } from './utils/type/Voter';
contract('Voting', (accounts: Truffle.Accounts) => {
	type ttp = Truffle.TransactionResponse<AllEvents> | undefined;
	const date: Date = new Date();
	const account: Account = {
		owner: accounts[0],
		firstVoter: accounts[1],
		secondVoter: accounts[2],
		thirdVoter: accounts[3],
		fourVoter: accounts[4],
		fiveVoter: accounts[5],
		notRegistered: accounts[6]
	}
	let VotingInstance: VotingInstance;
	let voter:ttp, proposal: ttp, vote: ttp, tally: ttp, status: ttp, votingSession: ttp;
	const startDate = date.getTime();
	const startVoting = date.setDate(11);
	const endDate = date.setDate(18);
	const newSession: Session = {startDate,startVoting,endDate};

	describe('action', () => {
		const arrayVoters: string[] = [account.firstVoter, account.secondVoter, account.thirdVoter, account.fourVoter, account.fiveVoter];
		describe.skip('Registering Voters', () => {
			context('one by one', () => {
				before(async () => {VotingInstance = await Voting.new({from: account.owner})});
				for (const addr of arrayVoters) {
					it(`should store ${addr} in the voting session mapping 0`, async () => {
						voter = await VotingInstance.voterRegistered(addr, 0 , {from: account.owner});
						expect(voter).to.be.ok;
					});
					it('get event voter registered', () =>{
						expectEvent(voter, 'VoterRegistered', {voterAddress:addr});
					});
					it('test if isRegistered', async () =>{
						const getVoter: Voter = await VotingInstance.getVoter(addr, 0, {from: account.owner});
						expect(getVoter.isRegistered).to.equal(true);
					});
				}
			});
			context('multiple', () =>{
				before(async () => {VotingInstance = await Voting.new({from: account.owner})});
				it(`should store multiple in the voting session mapping 0`, async () => {
					voter = await VotingInstance.votersRegistered(arrayVoters, 0 , {from: account.owner});
					expect(voter).to.be.ok;
				});
				it('get event voter registered', () =>{
					expectEvent(voter, 'VotersRegistered', {votersAddress:arrayVoters});
				});
				for (const addr of arrayVoters) {
					it(`test if ${addr} isRegistered`, async () =>{
						const getVoter: Voter = await VotingInstance.getVoter(addr, 0, {from: account.owner});
						expect(getVoter.isRegistered).to.equal(true);
					});
				}
			});
		});
		describe('Excluded Voter', () =>{
			beforeEach(async () => {
				VotingInstance = await Voting.new({from: account.owner});
				for (const addr of arrayVoters) {
					await VotingInstance.getVoter(addr, 0, {from: account.owner});
				}
			});
			context('one by one', () => {
				for (const addr of arrayVoters) {
					it(`should exclude ${addr} in the voting session mapping 0`, async () => {
						voter = await VotingInstance.voterExcluded(addr, 0 , {from: account.owner});
						expect(voter).to.be.ok;
					});
					it('get event voter excluded', () =>{
						expectEvent(voter, 'VoterExcluded', {voterAddress:addr});
					});
					it('test if is not registered', async () =>{
						const getVoter: Voter = await VotingInstance.getVoter(addr, 0, {from: account.owner});
						expect(getVoter.isRegistered).to.equal(false);
					});
				}
			});
			context('multiple', () =>{
				it(`should excluded multiple in the voting session mapping 0`, async () => {
					voter = await VotingInstance.votersExcluded(arrayVoters, 0 , {from: account.owner});
					expect(voter).to.be.ok;
				});
				it('get event voter excluded', () =>{
					expectEvent(voter, 'VotersExcluded', {votersAddress:arrayVoters});
				});
				for (const addr of arrayVoters) {
					it(`test if ${addr} is not registered`, async () =>{
						const getVoter: Voter = await VotingInstance.getVoter(addr, 0, {from: account.owner});
						expect(getVoter.isRegistered).to.equal(false);
					});
				}
			});
		});
		describe.skip('Start Voting', () => {
			before(async () => {VotingInstance = await Voting.new({from: account.owner})});
			it('should store a new voting session',async () =>{
				const newSession: Session = {startDate,startVoting,endDate};
				votingSession = await VotingInstance.startVoting(newSession, new BN(0), {from: account.owner});
				expect(votingSession).to.be.ok;
			});
			it('get event voting started', () =>{
				expectEvent(votingSession, 'VotingStarted', {lastSession:new BN(1)});
			});
			it('test to get a voting session', async () => {
				const getSession: Session = await VotingInstance.getVotingSession(new BN(0), {from: account.owner});
				expect(getSession.startDate).to.be.bignumber.equal(new BN(startDate))
				expect(getSession.startVoting).to.be.bignumber.equal(new BN(startVoting))
				expect(getSession.endDate).to.be.bignumber.equal(new BN(endDate))
			});
		});
		describe.skip('Workflow Status', () =>{
			before(async () => {
				VotingInstance = await Voting.new({from: account.owner});
				await VotingInstance.startVoting(newSession, new BN(0), {from: account.owner});
			});
			for (let i: number = 0; i < 6; i++) {
				if (i < 4){
					it(`Change Workflow Status from i: ${i} to ${i+1}`,async () => {
						status = await VotingInstance.nextWorkflowStatus(0,{from: account.owner});
						expectEvent(status, 'WorkflowStatusChange', {previousStatus: new BN(i), newStatus: new BN(i+1)});
					});
				}else if(i == 4){
					it(`Change Workflow Status from i: ${i} to ${i+1}`,async () => {
						expectRevert(VotingInstance.nextWorkflowStatus(0,{from: account.owner}), 'start tally votes for this session');
					});
					it('should give a tally of the votes', async () => {
						tally = await VotingInstance.tallyVotes(0,{from: account.owner});
						expect(tally).to.be.ok;
					});
				}else{
					it(`Change Workflow Status from i: ${i} to ${i+1}`,async () => {
						expectRevert(VotingInstance.nextWorkflowStatus(0,{from: account.owner}), 'this session is over');
					});
				}
			}
		});
	});
});