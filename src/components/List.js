import { ethers } from "ethers";

function List({ toggleCreate, fee, provider, launcher }) {
  async function createHandler(form) {
    const name = form.get("name");
    const ticker = form.get("symbol");

    const signer = await provider.getSigner();

    const transaction = await launcher
      .connect(signer)
      .createMeme(name, ticker, { value: fee });
    await transaction.wait();
    toggleCreate();
  }

  return (
    <div className="list">
      <h2>create new meme</h2>

      <div className="list_description">
        <p>fee: {ethers.formatUnits(fee, 18)} ETH</p>
      </div>

      <form action={createHandler}>
        <input type="text" name="name" placeholder="name" />
        <input type="text" name="symbol" placeholder="symbol" />
        <input type="submit" value="[ create ]" />
      </form>

      <button onClick={toggleCreate} className="btn--fancy">
        [ cancel ]
      </button>
    </div>
  );
}

export default List;
