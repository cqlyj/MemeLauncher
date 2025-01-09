"use client";

import Header from "../components/Header";
import List from "../components/List";
import { useState, useEffect } from "react";
import { Contract, ethers } from "ethers";
import { getContractData } from "@/constants";

export default function Home() {
  const [provider, setProvider] = useState(null);
  const [account, setAccount] = useState(null);
  const [launcher, setLauncher] = useState(null);
  const [fee, setFee] = useState(0);
  const [showCreate, setShowCreate] = useState(false);

  function toggleCreate() {
    showCreate ? setShowCreate(false) : setShowCreate(true);
  }

  async function loadBlockchainData() {
    const provider = new ethers.BrowserProvider(window.ethereum);
    setProvider(provider);

    const network = await provider.getNetwork();
    const chainId = network.chainId;

    const { abi, contractTransaction } = getContractData(chainId);
    const contractAddress = contractTransaction.transactions[0].contractAddress;

    const launcher = new Contract(contractAddress, abi, provider);
    setLauncher(launcher);
    const fee = await launcher.getFee();
    setFee(fee);
  }

  useEffect(() => {
    if (window.ethereum) {
      loadBlockchainData();
    }
  }, []);

  return (
    <div className="page">
      <Header account={account} setAccount={setAccount} />
      <main>
        <div className="create">
          <button
            onClick={launcher && account && toggleCreate}
            className="btn--fancy"
          >
            {!launcher
              ? "[ contract not deployed on this chain ] "
              : !account
              ? "[ please connect your wallet ]"
              : "[ Create A New MEME ]"}
          </button>
        </div>
      </main>

      {showCreate && (
        <List
          toggleCreate={toggleCreate}
          fee={fee}
          provider={provider}
          launcher={launcher}
        />
      )}
    </div>
  );
}
