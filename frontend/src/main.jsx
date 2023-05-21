import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

import { Battleground, CreateBattle, Battle, Home, JoinBattle, LandingPage } from './page';
import { OnboardModal } from './components';
import { GlobalContextProvider } from './context';
import './index.css';


ReactDOM.createRoot(document.getElementById('root')).render(
  <BrowserRouter>
    <Routes>
      <Route path="/" element={<LandingPage />} />
      {/* after user click on play button in the landing page */}
      <Route
        path="/game"
        element={
          <GlobalContextProvider>
            <Home />
            <OnboardModal />
          </GlobalContextProvider>
        }
      />
      <Route
        path="/battleground"
        element={
          <GlobalContextProvider>
            <Battleground />
            <OnboardModal />
          </GlobalContextProvider>
        }
      />
      <Route
        path="/battle/:battleName"
        element={
          <GlobalContextProvider>
            <Battle />
            <OnboardModal />
          </GlobalContextProvider>
        }
      />
      <Route
        path="/create-battle"
        element={
          <GlobalContextProvider>
            <CreateBattle />
            <OnboardModal />
          </GlobalContextProvider>
        }
      />
      <Route
        path="/join-battle"
        element={
          <GlobalContextProvider>
            <JoinBattle />
            <OnboardModal />
          </GlobalContextProvider>
        }
      />
    </Routes>
  </BrowserRouter>
);
