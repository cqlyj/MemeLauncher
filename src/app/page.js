"use client";

import Header from "../components/Header";
import List from "../components/List";
import Meme from "../components/Meme";
import Trade from "../components/Trade";
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
  const [showTrade, setShowTrade] = useState(false);
  const [memes, setMemes] = useState([]);
  const [meme, setMeme] = useState(null);

  function toggleCreate() {
    showCreate ? setShowCreate(false) : setShowCreate(true);
  }

  function toggleTrade(meme) {
    setMeme(meme);
    showTrade ? setShowTrade(false) : setShowTrade(true);
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
  }, [showCreate, showTrade]);

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
        <div className="listings">
          <h1>new listings</h1>

          <div className="tokens">
            {!account ? (
              <p>please connect wallet</p>
            ) : memes.length === 0 ? (
              <p>No tokens listed</p>
            ) : (
              memes.map((meme, index) => (
                <Meme toggleTrade={toggleTrade} meme={meme} key={index} />
              ))
            )}
          </div>
        </div>
        {showCreate && (
          <List
            toggleCreate={toggleCreate}
            fee={fee}
            provider={provider}
            launcher={launcher}
          />
        )}

        {showTrade && (
          <Trade
            toggleTrade={toggleTrade}
            meme={meme}
            provider={provider}
            launcher={launcher}
          />
        )}
      </main>
    </div>
  );
}
