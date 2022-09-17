// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract AucEngine
{
    address public owner;
    uint constant DURATION = 2 days;
    uint constant FEE = 10; // 10% - организатору    
    // вместо constant можно использовать immutable

    // Class
    struct Auction
    {
        address payable seller;
        uint startingPrice;
        uint finalPrice;
        uint startsAt;
        uint endsAt;
        uint discountRate;
        string item;
        bool stopped;
    }

    // Динамический массив объектов класса
    Auction[] public auctions;

    // Запись в журнал событий
    event AuctionCreated(uint index, string itemName, uint startingprice, uint duration);
    event AuctionEnded(uint index, uint finalPrice, address winner);

    // Конструктор
    constructor()
    {
        owner = msg.sender;
    }

    // calldata - неизменяемая переменная
    // Функция для создания аукциона
    function createAuction(uint _startingPrice, uint _discountRate, string calldata _item, uint _duration) external 
    {
        // Тернарная операция
        uint duration = _duration == 0 ? DURATION : _duration;

        require(_startingPrice >= _discountRate * _duration, "Incorrect starting price.");

        // Создание объекта класса
        Auction memory newAuction = Auction({
            seller: payable(msg.sender),
            startingPrice: _startingPrice,
            finalPrice: _startingPrice,
            discountRate: _discountRate,
            startsAt: block.timestamp,
            endsAt: block.timestamp + duration,
            item: _item,
            stopped: false
        });

        // Добавление нового объекта в динамический массив объектов
        auctions.push(newAuction);

        // Запись в журнал событий, который может быть прочитан, с помощью, к примеру, React
        emit AuctionCreated(auctions.length - 1, _item, _startingPrice, duration);
    }

    // Функция для получения стоиомсти товра на аукционе
    function getPriceFor(uint index) public view returns(uint)
    {
        // Текущий аукцион
        Auction storage currentAuction = auctions[index];

        // Проверка на то, не остановлен ли аукцион
        require(!currentAuction.stopped, "Auction is stopped.");

        // Расчёт прошедшего времени, для расчёта скидки на товар
        uint elapsed = block.timestamp - currentAuction.startsAt;

        // Расчёт скидки по прошедшему времени
        uint discount = currentAuction.discountRate * elapsed;

        // Возвращение текущей стоимости
        return currentAuction.startingPrice - discount;
    }

    function buy(uint index) external payable 
    {
        // Текущий аукцион, помещающися в память. memory только для считывания данных, не изменения
        Auction memory currentAuction = auctions[index];

        // Проверка на то, не остановлен ли аукцион
        require(!currentAuction.stopped, "Auction is stopped.");

        // Проверка на то, не подошло ли время конца аукциона
        require(block.timestamp < currentAuction.endsAt, "Auction has ended.");

        // Узнаём цену на товар, который пользователь хочет купить
        uint currentPrice = getPriceFor(index);

        // Проверка на то, достаточно ли средств у пользователя для покупки товара
        require(msg.value >= currentPrice, "Not enough funds!");
        
        // Останавливаем аукцион
        currentAuction.stopped = true;

        // Устанавливаем итоговую цену товара на аукционе
        currentAuction.finalPrice = currentPrice;

        // Получаем разницу количества переданных средств с текущей стоимость товара
        uint refund = msg.value - currentPrice;

        // Возврат покупателю денег, если он внёс лишние средства
        if (refund > 0)
        {
            payable(msg.sender).transfer(refund);
        }
 
        // Передача продавцу средств, за вычетом процентов для площадки, на которой проходит аукцион (для примера - 10%)
        currentAuction.seller.transfer(
            currentPrice - ((currentPrice * FEE) / 100)
        );
        // Если товар был куплен за 500 у.е. то расчёт будет следующим:
        // 500 - (500 * 10) / 100 = 500 - 50 = 450

        // Запись в журнал событий о том что событие произошло
        emit AuctionEnded(index, currentPrice, msg.sender);
    }
}