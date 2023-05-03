import React from 'react';
import backgroundImage from '../assets/bg1.png'
const Home = () => {
  return (
    <div>
      <h1 className="text-5xl p-3">KRYPTORENA</h1>
      <h2 className="text-3xl p-3">YOU, LUCK, & REWARDS</h2>
      <p className="text-xl p-3">Made with 💜 by BALENDU, ROBERTO, ERIC, ROSE</p>


     
        <img src={backgroundImage} alt="hero-img" className="w-full xl:h-full object-cover" />
     
    </div>

     
  )
};

export default Home;