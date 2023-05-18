import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

import Home from './page/Home';
import Games from './page/Games';
import './index.css';
import {PlayerOnboarding} from './components';
import { GlobalContextProvider } from './context';

ReactDOM.createRoot(document.getElementById('root')).render(
  <BrowserRouter>
    <GlobalContextProvider>
      <PlayerOnboarding />
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/games" element={<Games />}/>
      </Routes>
    </GlobalContextProvider>
  
  </BrowserRouter>,
);
