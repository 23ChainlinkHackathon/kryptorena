import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import { ethers } from 'ethers';
import Web3Modal from 'web3modal';
import { useNavigate } from 'react-router-dom';
import { PlayerOnboarding } from '../components';
import { ABI, ADDRESS} from '../contract'

const GlobalContext = createContext();

export const GlobalContextProvider = ({children}) => {
    const [walletAddress, setWalletAddress] = useState('');
    const [val, setVal]= useState(2);

    const updateWallet = async () => {
        const accounts = await window?.ethereum?.request({ method: 'eth_requestAccounts' });
        if (accounts) setWalletAddress(accounts[0]);
    }


    useEffect(() => {
        updateWallet();
        window?.ethereum?.on('accountsChanged', updateWallet);
    }, []);

    const createEventListeners = ({walletAddress}) => {
        console.log('new player added');
    }

    useEffect(() => {
        if (val === -1) {
            createEventListeners({
                walletAddress,
            });
        }
    }, [val]);

    const values = {
        walletAddress,
        updateWallet,
        val,
        setVal,
    }

    return (
        <GlobalContext.Provider
            value = {values}
            >
                {children}
            </GlobalContext.Provider>
    )
}

export const useGlobalContext = () => useContext(GlobalContext);