"use client";

import Header from "../components/Header";
import List from "../components/List";
import { useState, useEffect } from "react";
import { Contract, ethers } from "ethers";
import { getContractData } from "@/constants";
import images from "./images.json";

export default function Home() {
  const [provider, setProvider] = useState(null);
  const [account, setAccount] = useState(null);
  const [launcher, setLauncher] = useState(null);
  const [fee, setFee] = useState(0);
  const [showCreate, setShowCreate] = useState(false);
  const [memes, setMemes] = useState([]);

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

    const totalMemes = await launcher.getTotalMemes();
    const memes = [];

    for (let i = 0; i < totalMemes; i++) {
      // for now the images are pre-defined
      // only 6 images are available
      // this will be updated in the future
      if (i === 6) {
        break;
      }

      const memeSale = await launcher.getMemeSale(i);
      console.log(memeSale);

      const meme = {
        meme: memeSale.meme,
        name: memeSale.name,
        creator: memeSale.creator,
        sold: memeSale.sold,
        ethRaised: memeSale.ethRaised,
        isOpen: memeSale.isOpen,
        image: images[i],
      };
      memes.push(meme);

      setMemes(memes.reverse());

      console.log(memes);
    }
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
