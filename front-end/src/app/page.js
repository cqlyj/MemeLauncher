"use client";

import Header from "../components/Header";
import { useState, useEffect, use } from "react";
import { ethers } from "ethers";

export default function Home() {
  const [provider, setProvider] = useState(null);
  const [account, setAccount] = useState(null);

  async function loadBlockchainData() {
    const provider = new ethers.BrowserProvider(window.ethereum);
    setProvider(provider);
  }

  useEffect(() => {
    if (window.ethereum) {
      loadBlockchainData();
    }
  }, []);

  return (
    <div className="page">
      <Header account={account} setAccount={setAccount} />
    </div>
  );
}
