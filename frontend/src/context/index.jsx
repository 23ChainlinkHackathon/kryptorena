import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import { ethers } from 'ethers';
import Web3Modal from 'web3modal';
import { useNavigate } from 'react-router-dom';


const GlobalContext = createContext();

export const GlobalContextProvider = ({children}) => {
    const [walletAddress, setWalletAddress] = useState('');

    const updateWallet = async () => {
        const accounts = await window?.ethereum?.request({ method: 'eth_requestAccounts' });
        if (accounts) setWalletAddress(accounts[0]);
    }


    useEffect(() => {
        updateWallet();
        window?.ethereum?.on('accountsChanged', updateWallet);
    }, []);


    return (
        <GlobalContext.Provider
            value = {{
                walletAddress,
                updateWallet,
            }}
            >
                {children}
            </GlobalContext.Provider>
    )
}