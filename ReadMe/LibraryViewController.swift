/// Copyright (c) 2020 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit

class LibraryHeaderView: UITableViewHeaderFooterView {
  static let reuseIdentifier = "\(LibraryHeaderView.self)"
  @IBOutlet var titleLabel: UILabel!
}

enum SortStyle {
  case title
  case author
  case readMe
}

enum Section: String, CaseIterable {
  case addNew
  case readMe = "Read Me!"
  case finished = "Finished!"
}

class LibraryViewController: UITableViewController {
  
  var dataSource: LibraryDataSource!
  
  @IBOutlet var sortButtons: [UIBarButtonItem]!
  
  @IBAction func sortByTitle(_ sender: UIBarButtonItem) {
    dataSource.update(sortStyle: .title)
    updateTintColors(tappedButton: sender)
  }
  
  @IBAction func sortByAuthor(_ sender: UIBarButtonItem) {
    dataSource.update(sortStyle: .author)
    updateTintColors(tappedButton: sender)
  }
  
  @IBAction func sortByReadMe(_ sender: UIBarButtonItem) {
    dataSource.update(sortStyle: .readMe)
    updateTintColors(tappedButton: sender)
  }
  
  func updateTintColors(tappedButton: UIBarButtonItem) {
    sortButtons.forEach { button in
      button.tintColor = button == tappedButton
        ? button.customView?.tintColor
        : .secondaryLabel
    }
  }
  
  @IBSegueAction func showDetailView(_ coder: NSCoder) -> DetailViewController? {
    guard let indexPath = tableView.indexPathForSelectedRow,
          let book  = dataSource.itemIdentifier(for: indexPath)
    else { fatalError("Nothing selected!") }
    return DetailViewController(coder: coder, book: book)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = editButtonItem
    
    tableView.register(UINib(nibName: "\(LibraryHeaderView.self)", bundle: nil), forHeaderFooterViewReuseIdentifier: LibraryHeaderView.reuseIdentifier)
    
    configureDataSource()
    dataSource.update(sortStyle: .readMe)
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    dataSource.update(sortStyle: dataSource.currentSortStyle)
  }
  
  // MARK:- Delegate
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return section == 1 ? "Read Me!" : nil
  }
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    if section == 0 { return nil }
    
    guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: LibraryHeaderView.reuseIdentifier) as? LibraryHeaderView
    else { return nil }
    
    headerView.titleLabel.text = Section.allCases[section].rawValue
    return headerView
  }
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return section != 0 ? 60 : 0
  }
  
  // MARK:- Data Source
  func configureDataSource() {
    dataSource = LibraryDataSource(tableView: tableView) {
      tableView, indexPath, book -> UITableViewCell? in
      if indexPath == IndexPath(row: 0, section: 0) {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NewBookCell", for: indexPath)
        return cell
      }
      
      guard let cell = tableView.dequeueReusableCell(withIdentifier: "\(BookCell.self)", for: indexPath) as? BookCell
      else { fatalError("Could not create BookCell") }
      cell.titleLabel.text = book.title
      cell.authorLabel.text = book.author
      cell.bookThumbnail.image = book.image ?? LibrarySymbol.letterSquare(letter: book.title.first).image
      cell.bookThumbnail.layer.cornerRadius = 12
      
      if let review = book.review {
        cell.reviewLabel.text = review
        cell.reviewLabel.isHidden = false
      }
      
      cell.readMeBookmark.isHidden = !book.readMe
      return cell
    }
  }
}

class LibraryDataSource: UITableViewDiffableDataSource<Section, Book> {
  var currentSortStyle: SortStyle = .title
  
  func update(sortStyle: SortStyle, animatingDifferences: Bool = true) {
    currentSortStyle = sortStyle
    
    var newSnapshot = NSDiffableDataSourceSnapshot<Section, Book>()
    newSnapshot.appendSections(Section.allCases)
    let booksByReadMe: [Bool: [Book]] = Dictionary(grouping: Library.books, by: \.readMe)
    for (readMe, books) in booksByReadMe {
      var sortedBooks: [Book]
      switch sortStyle {
      case .title:
        sortedBooks = books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
      case .author:
        sortedBooks = books.sorted { $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending }
      case .readMe:
        sortedBooks = books
      }
      newSnapshot.appendItems(sortedBooks, toSection: readMe ? .readMe : .finished)
    }
    newSnapshot.appendItems([Book.mockBook], toSection: .addNew)
    apply(newSnapshot, animatingDifferences: animatingDifferences)
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    indexPath.section == snapshot().indexOfSection(.addNew) ? false : true
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      guard let book = self.itemIdentifier(for: indexPath) else { return }
      Library.delete(book: book)
      update(sortStyle: currentSortStyle)
    }
  }
  
  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    if indexPath.section != snapshot().indexOfSection(.readMe)
        || currentSortStyle != .readMe {
      return false
    } else {
      return true
    }
  }
  
  override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    guard
      sourceIndexPath != destinationIndexPath,
      sourceIndexPath.section == destinationIndexPath.section,
      let bookToMove = itemIdentifier(for: sourceIndexPath),
      let bookAtDestination = itemIdentifier(for: destinationIndexPath)
    else {
      apply(snapshot(), animatingDifferences: false)
      return
    }
    
    Library.reorderBooks(bookToMove: bookToMove, bookAtDestination: bookAtDestination)
    update(sortStyle: currentSortStyle, animatingDifferences: false)
  }
}
