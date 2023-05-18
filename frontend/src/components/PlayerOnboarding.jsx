import {useState, useEffect} from 'react';
import Modal from 'react-modal';
import { useGlobalContext } from '../context';
import { getChainId } from 'web3modal';


const PlayerOnboarding = () => {
    // wallet connection -> metamask for the time being
    // fuji chain should be used by user
    // avax tokens of the user
    // check link tokens in the smartcontract

    const { updateWallet } = useGlobalContext();

    const [val, setVal] = useState(-1);

    
    // helper functions to onboardingHelper
    const isEth = () => {
        if(window.ethereum) {
            return true;
        } else {
            return false;
        }
    }

    const getChainId = () => {
        if(isEth()) {
            return parseInt(window.ethereum.chainId, 16);
        }
        return 0;
    }

    const reqAccount = async () => {
        let currAccount = 0x0;
        if (isEthereum() && getChainID() !== 0) {
            let accounts = await window.ethereum.request({ method: 'eth_accounts' });
            accounts = await handleConnection(accounts);
            currAccount = accounts[0];
        }
        return currAccount;
    };

    const reqBal = async () => {
        let currBal =0;
        if (isEth()) {
            try{
                currBal = await window.ethereum.request({
                    method: 'eth_getBalance',
                    params: [currAccount, 'latest'],
                });
                currBal = parseInt(currBal, 16)/ 1e18;
                return {currBal, err: false};
            } catch (err) {
                return {currBal, err: true};
            }
        }
        return {currBal, err:true};
    }
    

    const GetParams = async () => {
        const impValues = {
            isError: false,
            message: '',
            val: -1,
            balance: 0,
            account: '0x0',
        }
        if(!isEth()){
            setVal(1);
            impValues.val = 1;
            console.log("no eth wallet");
            return impValues;

        }

        const currAcc = await reqAccount();
        if(currAcc === 0x0) {
            setVal(2);
            impValues.val = 2;
            return impValues;
        }

        if(getChainId() !== 43113) {
            setVal(3);
            impValues.val = 3;
            return impValues;
        }

        const { currBal, err} = await reqBal(curAcc);
        if(err) {
            impValues.isError = true;
            impValues.message = 'Error fetching balance!';
            return impValues;
        }
        impValues.balance = currBal;

        if (currBal < 0.5) {
            setVal(4);
            impValues.val = 4;
            return impValues;
        }

        return impValues;


    }
    // switch Network
    const NetworkSwitch = async () => {
        await window?.ethereum?.request({
            method: 'wallet_addEthereumChain',
            params: [{
              chainId: '0xA869',
              chainName: 'Fuji C-Chain',
              nativeCurrency: {
                name: 'AVAX',
                symbol: 'AVAX',
                decimals: 18,
              },
              rpcUrls: ['https://api.avax-test.network/ext/bc/C/rpc'],
              blockExplorerUrls: ['https://testnet.snowtrace.io'],
            }],
          }).catch((error) => {
            console.log(error);
          });
    }


    // main func
    const onboardingHelper = (value) => {
        switch(value) {
            case 1:
                return (
                    <>
                        <p>
                            Hey please install the Metamask wallet and try again!
                        </p>
                        <Button 
                            title="Metamask donwnload" 
                            handleClick = {() => window.open('https://metamask.io/download/', '_blank')}                        
                        />
                    </>
                );
            
            case 2:
                return (
                    <>
                        <p>
                            To play this game you need to connect your ethereum wallet
                        </p>
                        <Button 
                            title = "Connect Wallet"
                            handleClick = {updateWallet}
                        />
                    </>
                );
            
            case 3:
                return (
                    <>
                        <p>
                            For now we support Fuji C-chain,
                        </p>
                        <Button 
                            title = "Switch Network"
                            handleClick = {NetworkSwitch}
                        />
                    </>
                );

            case 4:
                return (
                    <>
                        <p>
                            Almost there, now let's help you get some AVAX to play the game
                        </p>
                        <Button 
                            title="2 AVAX" 
                            handleClick = {() => window.open('https://faucet.avax.network/', '_blank')}                        
                        />
                    </>
                );
            
            default:
                return <p>Awesome! We are all set to play. LET'S GOOOOOOOOO</p>

        }
    };

    return(
        <Modal>
            {onboardingHelper(val)}
        </Modal>
    )


}

export default PlayerOnboarding;